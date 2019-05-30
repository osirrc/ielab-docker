// package trecresults provides helper functions for reading and writing trec results files
// suitable for using with treceval.
//
// It has three main concepts:
//
// ResultFile: Contains a map of results for all topics contained in this results file.
//
// ResultList: A slice containing the results for this topic.
//
// Result: The data that describes a single entry in a result list.
package trecresults

import (
	"bufio"
	"errors"
	"fmt"
	"io"
	"sort"
	"strconv"
	"strings"
)

// ResultFile contains a map of all the result lists, indexed by topic ID.
type ResultFile struct {
	Results map[string]ResultList
}

// ResultList contains a slice of pointers to results for a single topic.
//
// ResultList impliments sort.Interface, allowing it to be sorted by score.
// If the score is modified. The swap implementation also updates the rank scored
// by each result.
type ResultList []*Result

// Result is a single entry in a trec result list.
//
// Implements the fmt.Stringer interface, allowing results to be printed.
type Result struct {
	Topic     string  // The integer topic ID.
	Iteration string  // The iteration this run is associated with (ignored by treceval).
	DocId     string  // The document ID for this result.
	Rank      int64   // The rank in the result list.
	Score     float64 // The score the document received for this topic.
	RunName   string  // The name of the run this result is from.
}

// NewResultFile is the constructor for a ResultFile pointer.
func NewResultFile() *ResultFile {
	return &ResultFile{make(map[string]ResultList)}
}

// Len method for sort.Interface.
func (r ResultList) Len() int { return len(r) }

// Swap method for sort.Interface. Also updates the ranks of the results correctly.
func (r ResultList) Swap(i, j int) {
	r[i], r[j] = r[j], r[i]
	r[i].Rank = int64(i)
	r[j].Rank = int64(j)
}

// Less method for sort.Interface. Results are sorted by decreasing score.
func (r ResultList) Less(i, j int) bool {
	return r[i].Score > r[j].Score
}

// String method for fmt.Stringer. Formats a result structure into the original string representation that can be used with treceval.
func (r *Result) String() string {
	return fmt.Sprintf("%s %s %s %d %g %s", r.Topic, r.Iteration, r.DocId, r.Rank, r.Score, r.RunName)
}

// ResultFromLine creates a result structure from a single line from a results file.
//
// Returns parsing errors if any of the integer or float fields do not parse.
//
// Returns an error if there are not 6 fields in the result line.
//
// On error, a nil result is returned.
func ResultFromLine(line string) (*Result, error) {
	split := strings.Fields(line)

	if len(split) != 6 {
		err := errors.New("Incorrect number of fields in result string: " + line)
		return nil, err
	}

	topic := split[0]
	iteration := split[1]
	docId := split[2]

	rank, err := strconv.ParseInt(split[3], 10, 0)
	if err != nil {
		return nil, err
	}

	score, err := strconv.ParseFloat(split[4], 64)
	if err != nil {
		return nil, err
	}
	runname := split[5]

	return &Result{topic, iteration, docId, rank, score, runname}, nil
}

// ResultsFromReader returns a ResultsFile object created from the
// provided reader (eg a file).
//
// On errors, a ResultFile containing every Result and ResultList read before the error was encountered is
// returned, along with the error.
func ResultsFromReader(file io.Reader) (ResultFile, error) {
	var rf ResultFile
	rf.Results = make(map[string]ResultList)

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		r, err := ResultFromLine(scanner.Text())
		results, ok := rf.Results[r.Topic]
		if !ok {
			results = make([]*Result, 0, 0)
			rf.Results[r.Topic] = results
		}

		if err != nil {
			return rf, err
		}
		rf.Results[r.Topic] = append(results, r)
	}

	if err := scanner.Err(); err != nil {
		return rf, err
	}
	return rf, nil
}

// RenameRun renames all results in this list. Useful for giving a run a new name
// after manipulation.
func (r ResultList) RenameRun(newName string) {
	for _, res := range r {
		res.RunName = newName
	}
}

// Sort sorts all result lists in this result file. Call this before printing if you
// have modified the scores.
func (r ResultFile) Sort() {
	for _, list := range r.Results {
		sort.Sort(list)
	}
}

// RenameRun renames the runs of all result lists in this result file.
//
// It calls RenameRun(newName) on each ResultList in this ResultFile.
func (r ResultFile) RenameRun(newName string) {
	for _, list := range r.Results {
		list.RenameRun(newName)
	}
}

// NormaliseLinear normalises the runs of all result lists in this result file.
//
// It calls NormaliseLinear() on each ResultList in this ResultFile.
func (r ResultFile) NormaliseLinear() {
	for _, list := range r.Results {
		list.NormaliseLinear()
	}
}

// NormaliseLinear operates on a slice of results, and normalises the score
// of each result by score (score - min)/(max - min). This puts scores
// in to the range 0-1, where 1 is the highest score, and 0 is the lowest.
//
// No assumptions are made as to whether the slice is pre-sorted.
func (r ResultList) NormaliseLinear() {
	if len(r) == 0 {
		return
	}
	max := r[0].Score
	min := r[0].Score
	for _, res := range r {
		if res.Score > max {
			max = res.Score
		}
		if res.Score < min {
			min = res.Score
		}
	}

	for _, res := range r {
		res.Score = (res.Score - min) / (max - min)
	}
}
