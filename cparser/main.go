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
	"unicode/utf8"
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
	Header   string       `xml:"HEADER,omitempty"`
	Trailer  string       `xml:"TRAILER,omitempty"`
	Text     InnerResult  `xml:"TEXT"`
}

type InnerResult struct {
	Value string `xml:",innerxml"`
}

type TRECWEBBody struct {
	XMLName  xml.Name     `xml:"BODY,omitempty"`
	Headline string       `xml:"HEADLINE,omitempty"`
	Slug     string       `xml:"SLUG,omitempty"`
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
		Type        string      `json:"type"`
		Subtype     string      `json:"subtype"`
		Mime        string      `json:"mime"`
		Content     interface{} `json:"content,omitempty"`
		Text        string      `json:"text,omitempty"`
		FullCaption string      `json:"full_caption,omitempty"`
		ImageURL    string      `json:"imageURL,omitempty"`
		ImageHeight int         `json:"image_height,omitempty"`
		ImageWidth  int         `json:"image_width,omitempty"`
		Blurb       string      `json:"blurb"`
		Role        string      `json:"role"`
		Bio         string      `json:"bio"`
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
		b, _ := ioutil.ReadAll(r)
		fmt.Println(string(b))
		panic(err)
		return nil, err
	}

	// Transform the doc into a TRECWEBDoc and clean it up.
	var j interface{}
	if d.Body != nil { // If the document has a body tag, it's probably NYT.
		j = struct {
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
	} else { // Otherwise, just put everything into TEXT.
		j = struct {
			DocNo string
			Text  string
		}{
			DocNo: strings.TrimSpace(d.DocNo),
			Text:  strings.TrimSpace(d.Text.Value),
		}
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

	for i, c := range d.Contents {
		d.Contents[i].Text = fmt.Sprintf("%v", c.Content)
		d.Contents[i].Content = ""
	}

	err = json.NewEncoder(buff).Encode(&d)
	return buff.Bytes(), err
}

func ParseWARC(r io.Reader) ([][]byte, error) {
	reader, err := warc.NewReader(r)
	if err != nil {
		return nil, err
	}
	records, err := reader.ReadAll()
	if err != nil {
		return nil, err
	}

	recs := make([][]byte, len(records))

	for i, rec := range records {
		buff := new(bytes.Buffer)
		err = json.NewEncoder(buff).Encode(rec)
		if err != nil {
			return nil, err
		}
		recs[i] = buff.Bytes()
	}

	return recs, nil
}

func ParseJSON(r io.Reader) ([]byte, error) {
	return ioutil.ReadAll(r)
}

func fixUtf(r rune) rune {
	if r == utf8.RuneError {
		return -1
	}
	return r
}

func main() {
	var (
		format            CollectionFormat = "trecweb"                                      // The default collection format.
		buff                               = new(bytes.Buffer)                              // Buffer to store the current document.
		state                              = Skipping                                       // State the collectionPath reader is in.
		xmlEntRe                           = regexp.MustCompile(`&.*;|&|\|`)                // Regex to filter out XML entities.
		xmlUnquotedAttrRe                  = regexp.MustCompile(`[a-zA-Z]+=[a-zA-Z0-9\-]+`) // Regex to remove unquoted XML attributes.
	)

	// The name and path of the collection.
	collectionName := os.Args[1]

	// Determine the parser for collections to use.
	format = CollectionFormat(os.Args[2])
	switch format {
	case TRECWEB:
	case TRECTEXT:
	case WashPost:
	case WARC:
	case JSON:
	default:
		log.Fatalln(fmt.Sprintf("%s is not a valid collection format", format))
	}

	if format == TRECTEXT || format == TRECWEB {
		parser := ParseTRECWEB

		// Read and parse the collectionPath.
		scanner := bufio.NewScanner(os.Stdin)
		for scanner.Scan() {
			t := xmlEntRe.ReplaceAllString(scanner.Text(), "")
			t = xmlUnquotedAttrRe.ReplaceAllString(t, "")
			t = strings.Map(fixUtf, t)
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
				_, err = os.Stdout.WriteString(fmt.Sprintf(`{ "index": { "_index": "%s" } }
%s`, collectionName, data))
				if err != nil {
					log.Fatalln(err)
				}
			}
		}
	} else if format == WashPost {
		data, err := ParseWP(os.Stdin)
		if err != nil {
			log.Fatalln(err)
		}
		_, err = os.Stdout.WriteString(fmt.Sprintf(`{ "index": { "_index": "%s" } }
%s`, collectionName, data))
		if err != nil {
			log.Fatalln(err)
		}
	} else if format == WARC {
		records, err := ParseWARC(os.Stdin)
		if err != nil {
			log.Fatalln(err)
		}
		for _, data := range records {
			_, err = os.Stdout.WriteString(fmt.Sprintf(`{ "index": { "_index": "%s" } }
%s`, collectionName, data))
			if err != nil {
				log.Fatalln(err)
			}
		}
	} else if format == JSON {
		data, err := ParseJSON(os.Stdin)
		if err != nil {
			log.Fatalln(err)
		}
		_, err = os.Stdout.WriteString(fmt.Sprintf(`{ "index": { "_index": "%s" } }
%s`, collectionName, data))
		if err != nil {
			log.Fatalln(err)
		}
	}
}
