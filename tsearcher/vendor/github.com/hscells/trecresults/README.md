
# trecresults
    import "github.com/TimothyJones/trecresults"

Package trecresults provides helper functions for reading and writing trec results files
suitable for using with treceval.

[![Build Status](https://travis-ci.org/TimothyJones/trecresults.svg?branch=master)](https://travis-ci.org/TimothyJones/trecresults)


It has three main concepts:

ResultFile: Contains a map of results for all topics contained in this results file

ResultList: A slice containing the results for this topic

Result: The data that describes a single entry in a result list







## type Qrel
``` go
type Qrel struct {
    Topic     int64  // The topic that this qrel is associated with
    Iteration string // Ignored by treceval
    DocId     string // the docid
    Score     int64  // the relevance score for this document
}
```








### func QrelFromLine
``` go
func QrelFromLine(line string) (*Qrel, error)
```
Creates a qrel structure from a single line from a results file.

Returns parsing errors if any of the integer or float fields do not parse.

Returns an error if there are not 4 fields in the result line.

On error, a nil result is returned.




## type Qrels
``` go
type Qrels map[string]*Qrel
```
Qrels is a map of docids to relevance value











## type QrelsFile
``` go
type QrelsFile struct {
    Qrels map[int64]Qrels
}
```
The result file contains a map of all qrels lists, indexed by topic ID.









### func NewQrelsFile
``` go
func NewQrelsFile() *QrelsFile
```
Constructor for a QrelsFile pointer


### func QrelsFromReader
``` go
func QrelsFromReader(file io.Reader) (QrelsFile, error)
```
This function returns a QrelsFile object created from the
provided reader (eg a file).

On errors, a QrelsFile containing all qrels read before the error was encountered is
returned, along with the error.




## type Result
``` go
type Result struct {
    Topic     int64   // the integer topic ID
    Iteration string  // the iteration this run is associated with (ignored by treceval)
    DocId     string  // the document ID for this result
    Rank      int64   // the rank in the result list
    Score     float64 // the score the document received for this topic
    RunName   string  // the name of the run this result is from
}
```
Describes a single entry in a trec result list.

Implements the fmt.Stringer interface, allowing results to be printed.









### func ResultFromLine
``` go
func ResultFromLine(line string) (*Result, error)
```
Creates a result structure from a single line from a results file.

Returns parsing errors if any of the integer or float fields do not parse.

Returns an error if there are not 6 fields in the result line.

On error, a nil result is returned.




### func (\*Result) String
``` go
func (r *Result) String() string
```
String method for fmt.Stringer. Formats a result structure into the original string representation that can be used with treceval.



## type ResultFile
``` go
type ResultFile struct {
    Results map[int64]ResultList
}
```
The result file contains a map of all the result lists, indexed by topic ID.









### func NewResultFile
``` go
func NewResultFile() *ResultFile
```
Constructor for a ResultFile pointer


### func ResultsFromReader
``` go
func ResultsFromReader(file io.Reader) (ResultFile, error)
```
This function returns a ResultsFile object created from the
provided reader (eg a file).

On errors, a ResultFile containing every Result and ResultList read before the error was encountered is
returned, along with the error.




### func (ResultFile) NormaliseLinear
``` go
func (r ResultFile) NormaliseLinear()
```
This function normalises the runs of all result lists in this result file.

It calls NormaliseLinear() on each ResultList in this ResultFile



### func (ResultFile) RenameRun
``` go
func (r ResultFile) RenameRun(newName string)
```
This function renames the runs of all result lists in this result file.

It calls RenameRun(newName) on each ResultList in this ResultFile



### func (ResultFile) Sort
``` go
func (r ResultFile) Sort()
```
This function sorts all result lists in this result file. Call this before printing if you
have modified the scores.



## type ResultList
``` go
type ResultList []*Result
```
ResultList contains a slice of pointers to results for a single topic.

ResultList impliments sort.Interface, allowing it to be sorted by score
if the score is modified. The swap implementation also updates the rank scored
by each result.











### func (ResultList) Len
``` go
func (r ResultList) Len() int
```
Length method for sort.Interface



### func (ResultList) Less
``` go
func (r ResultList) Less(i, j int) bool
```
Less method for sort.Interface. Results are sorted by decreasing score.



### func (ResultList) NormaliseLinear
``` go
func (r ResultList) NormaliseLinear()
```
This function operates on a slice of results, and normalises the score
of each result by score (score - min)/(max - min). This puts scores
in to the range 0-1, where 1 is the highest score, and 0 is the lowest.

No assumptions are made as to whether the slice is pre sorted



### func (ResultList) RenameRun
``` go
func (r ResultList) RenameRun(newName string)
```
This function renames all results in this list. Useful for giving a run a new name
after manipulation.



### func (ResultList) Swap
``` go
func (r ResultList) Swap(i, j int)
```
Swap method for sort.Interface. Also updates the ranks of the results correctly.









- - -
Generated by [godoc2md](http://godoc.org/github.com/davecheney/godoc2md)
