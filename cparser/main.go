// Package main implements a document parser and elasticsearch bulk index templater. The parser
// only works on files like NYT or AP, which have an XML structure.
package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"encoding/xml"
	"fmt"
	"github.com/datatogether/warc"
	"io"
	"io/ioutil"
	"log"
	"os"
	"regexp"
	"strings"
)

// Start and end tokens in TREC collections.
const (
	StartToken = "<DOC>"
	EndToken   = "</DOC>"
)

// Current state of the reader.
type readState int

const (
	Reading readState = iota
	Skipping
)

// Collection formats.
type CollectionFormat string

const (
	TRECWEB  CollectionFormat = "trecweb"
	TRECTEXT                  = "trectext"
	WashPost                  = "wp"
	WARC                      = "warc"
	JSON                      = "json"
)

type TRECWEBDoc struct {
	XMLName  xml.Name     `xml:"DOC,omitempty"`
	Body     *TRECWEBBody `xml:"BODY,omitempty"`
	DateTime string       `xml:"DATE_TIME,omitempty"`
	DocNo    string       `xml:"DOCNO,omitempty"`
	DocType  string       `xml:"DOCTYPE,omitempty"`
	Header   string       `xml:"HEADER"`
	Trailer  string       `xml:"TRAILER,omitempty"`
}

type TRECWEBBody struct {
	XMLName  xml.Name     `xml:"BODY,omitempty"`
	Headline string       `xml:"HEADLINE"`
	Slug     string       `xml:"SLUG"`
	Text     *TRECWEBText `xml:"TEXT,omitempty"`
}

type TRECWEBText struct {
	XMLName xml.Name `xml:"TEXT,omitempty"`
	P       []string `xml:"P"`
}

type WaPostArticle struct {
	Id            string `json:"id"`
	ArticleURL    string `json:"article_url"`
	Title         string `json:"title"`
	Author        string `json:"author"`
	PublishedDate int    `json:"published_date"`
	Type          string `json:"type"`
	Source        string `json:"source"`
	Contents      []struct {
		Type        string `json:"type"`
		Subtype     string `json:"subtype"`
		Mime        string `json:"mime"`
		Content     string `json:"content,omitempty"`
		FullCaption string `json:"full_caption,omitempty"`
		ImageURL    string `json:"imageURL,omitempty"`
		ImageHeight int    `json:"image_height,omitempty"`
		ImageWidth  int    `json:"image_width,omitempty"`
		Blurb       string `json:"blurb"`
		Role        string `json:"role"`
		Bio         string `json:"bio"`
	} `json:"contents"`
}

type CollectionParser func(r io.Reader) ([]byte, error)

func ParseTRECWEB(r io.Reader) ([]byte, error) {
	var (
		d    = TRECWEBDoc{}
		buff = new(bytes.Buffer)
	)
	// Decode the pseudo-xml data into a TRECWEBDoc.
	err := xml.NewDecoder(r).Decode(&d)
	if err != nil {
		panic(err)
		return nil, err
	}

	// Transform the doc into a TRECWEBDoc and clean it up.
	j := struct {
		Headline string
		Slug     string
		Text     string
		DateTime string
		DocNo    string
		DocType  string
		Header   string
		Trailer  string
	}{
		Headline: strings.TrimSpace(d.Body.Headline),
		Slug:     strings.TrimSpace(d.Body.Slug),
		Text:     strings.Join(d.Body.Text.P, " "),
		DateTime: strings.TrimSpace(d.DateTime),
		DocNo:    strings.TrimSpace(d.DocNo),
		DocType:  strings.TrimSpace(d.DocType),
		Header:   strings.TrimSpace(d.Header),
		Trailer:  strings.TrimSpace(d.Trailer),
	}

	// Encode the TRECWEBDoc into raw JSON.
	err = json.NewEncoder(buff).Encode(&j)
	if err != nil {
		return nil, err
	}
	return buff.Bytes(), nil
}

func ParseWP(r io.Reader) ([]byte, error) {
	var (
		d    WaPostArticle
		buff = new(bytes.Buffer)
	)
	err := json.NewDecoder(r).Decode(&d)
	if err != nil {
		return nil, err
	}
	err = json.NewEncoder(buff).Encode(&d)
	return buff.Bytes(), err
}

func ParseWARC(r io.Reader) ([]byte, error) {
	reader, err := warc.NewReader(r)
	if err != nil {
		return nil, err
	}
	records, err := reader.ReadAll()
	if err != nil {
		return nil, err
	}

	buff := new(bytes.Buffer)
	err = json.NewEncoder(buff).Encode(records)
	if err != nil {
		return nil, err
	}

	return buff.Bytes(), nil
}

func ParseJSON(r io.Reader) ([]byte, error) {
	return ioutil.ReadAll(r)
}

func main() {
	var (
		format CollectionFormat = "trecweb" // The default collection format.
		parser CollectionParser             // The method of parsing to use.
		buff   = new(bytes.Buffer)          // Buffer to store the current document.
		state  = Skipping                   // State the collectionPath reader is in.
		re     = regexp.MustCompile("&.*;") // Regex to filter out XML entities.
		i      int                          // Variable to track the document id.
	)

	// The name and path of the collection.
	collectionName := os.Args[1]

	// Determine the parser for collections to use.
	format = CollectionFormat(os.Args[2])
	switch format {
	case TRECWEB:
		parser = ParseTRECWEB
	case TRECTEXT:
		parser = ParseTRECWEB
	case WashPost:
		parser = ParseWP
	case WARC:
		parser = ParseWARC
	case JSON:
		parser = ParseJSON
	default:
		log.Fatalln(fmt.Sprintf("%s is not a valid collection format", format))
	}

	// Read and parse the collectionPath.
	scanner := bufio.NewScanner(os.Stdin)
	for scanner.Scan() {
		t := re.ReplaceAllString(scanner.Text(), "")
		if state == Skipping && t == StartToken {
			state = Reading
		}

		if state == Reading {
			_, err := buff.WriteString(t)
			if err != nil {
				log.Fatalln(err)
			}
		}

		if state == Reading && t == EndToken {
			state = Skipping
			data, err := parser(buff)
			if err != nil {
				log.Fatalln(err)
			}
			_, err = os.Stdout.WriteString(fmt.Sprintf(`{ "index": { "_index": "%s", "_id": "%d" } }
%s`, collectionName, i, data))
			if err != nil {
				log.Fatalln(err)
			}
			i++
		}
	}
}
