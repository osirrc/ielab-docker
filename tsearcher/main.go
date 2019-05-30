// Package main implements a topic parser and searcher.
package main

import (
	"bufio"
	"bytes"
	"context"
	"fmt"
	"github.com/hscells/trecresults"
	"github.com/olivere/elastic/v7"
	"io"
	"io/ioutil"
	"log"
	"os"
	"regexp"
	"strconv"
)

// Start and end tokens in TREC collections.
const (
	StartToken = "<top>"
	EndToken   = "</top>"
)

// Current state of the reader.
type readState int

const (
	Reading readState = iota
	Skipping
)

// Collection formats.
type TopicFormat string

const (
	TREC TopicFormat = "trec"
)

type Topic struct {
	Num   string
	Title string
	Desc  string
	Narr  string
}

func ParseTRECTopic(r io.Reader) (Topic, error) {

	const (
		num   string = "<num> Number:"
		title        = "<title>"
		desc         = "<desc> Description:"
		narr         = "<narr> Narrative:"
	)

	state := 0

	var (
		topic Topic
		buff  = new(bytes.Buffer)
	)

	b, err := ioutil.ReadAll(r)
	if err != nil {
		return topic, err
	}

	for _, c := range bytes.NewBuffer(b).String() {
		if c == '<' {
			switch state {
			case 1:
				topic.Num = buff.String()
			case 2:
				topic.Title = buff.String()
			case 3:
				topic.Desc = buff.String()
			case 4:
				topic.Narr = buff.String()
			}
			state = 0
			buff.Reset()
		}

		buff.WriteRune(c)
		if state == 0 {
			switch buff.String() {
			case num:
				state = 1
				buff.Reset()
			case title:
				state = 2
				buff.Reset()
			case desc:
				state = 3
				buff.Reset()
			case narr:
				state = 4
				buff.Reset()
			}
		}
	}
	return topic, nil
}

func main() {
	var (
		buff  = new(bytes.Buffer)          // Buffer to store the current document.
		state = Skipping                   // State the collection reader is in.
		re    = regexp.MustCompile("&.*;") // Regex to filter out XML entities.
	)

	collection := os.Args[1]
	topicFormat := TopicFormat(os.Args[2])
	switch topicFormat {
	case TREC:
		// There is only one format supported currently.
	default:
		log.Fatalf("%s is not a known topic format", topicFormat)
	}
	topK, err := strconv.Atoi(os.Args[3])
	if err != nil {
		log.Fatalln(err)
	}

	client, err := elastic.NewClient(elastic.SetURL("http://localhost:9200"))
	if err != nil {
		log.Fatalln(err)
	}

	// Read and parse the collection.
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
			// Obtain the topic.
			topic, err := ParseTRECTopic(buff)
			if err != nil {
				log.Fatalln(err)
			}
			// Execute the topic.
			search, err := client.
				Search(collection).
				Size(topK).
				Query(elastic.NewQueryStringQuery(topic.Title)).
				Do(context.Background())
			if err != nil {
				log.Fatalln(err)
			}
			// Process the search results and write to file.
			for i, hit := range search.Hits.Hits {
				t := trecresults.Result{
					Topic:     topic.Num,
					Iteration: "0",
					DocId:     hit.Id,
					Rank:      int64(i + 1),
					Score:     *hit.Score,
					RunName:   collection,
				}
				_, err := os.Stdout.WriteString(fmt.Sprintf("%s\n", t.String()))
				if err != nil {
					log.Fatalln(err)
				}
			}
		}
	}
}
