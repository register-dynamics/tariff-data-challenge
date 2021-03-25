# Tariffs Database Challenge

This is an implementation challenge that will test your ability to:

1. Quickly get to grips with a complex domain model
2. Write efficient database queries
3. Understand data through inspection of a database

## Context

### Commodity codes
A commodity code represents a product in a product classification system. For
example, the commodity code 0101 21 00 00 represents "Pure-bred breeding
animals". If you import pure-bred breeding animals, you would need to write this
commodity code on your import declaration.

Commodity codes are important because the taxes and controls applied on imports
are mainly determined by what product you are importing, and hence having the
correct commodity code is paramount. It is illegal to use an incorrect code.

| Commodity     | Suffix | Indents | Description                           |
|---------------|--------|---------|---------------------------------------|
| 0100 00 00 00 | 80     | 0       | LIVE ANIMALS                          |
| 0101 00 00 00 | 80     | 0       | Live horses, asses, mules and hinnies |
| 0101 21 00 00 | 10     | 1       |    Horses                             |
| 0101 21 00 00 | 80     | 2       |        Pure-bred breeding animals     |
| 0101 29 00 00 | 80     | 2       |        Other                          |
| 0101 29 10 00 | 80     | 3       |            For slaughter              |
| 0101 29 90 00 | 80     | 3       |            Other                      |
| 0101 30 00 00 | 80     | 1       |    Asses                              |
| 0101 90 00 00 | 80     | 1       |    Other                              |

Codes exist in a tree structure. The parent of "Pure-bred breeding animals" is
"Horses" – so in fact, the commodity code 0101 21 00 00 only applies to horses
that are pure-bred and for breeding. A pure-bred breeding bull would not fall
under 0101 21 00 00. Hence, understanding the _ancestors_ of a commodity code is
important as well.

In the tree above, you can see 0101 21 00 00 listed twice – once for "Horses"
and once for "Pure-bred breeding animals". This is because "Horses" is an
_intermediate line_ – it is not a legally recognised code, but exists just to
provide more structure to the tree. This is where the "suffix" comes into play –
a commodity code can exist multiple times with different suffixes, and only the
code with the suffix marked "80" can be declared or referenced in legislation.

Commodity codes hence have the following properties:

| Field               | Data type       | Comment                                                                                |
|---------------------|-----------------|----------------------------------------------------------------------------------------|
| SID                 | int             | A unique identifier                                                                    |
| Code                | char(10)        | The 10 digit commodity code                                                            |
| Suffix              | char(2)         | The 2 digit suffix – intermediate codes have a value that is not "80"                  |
| Description         | text            | An English description of what the code represents                                     |
| Validity start date | date            | The first day on which the code is usable                                              |
| Validity end date   | date (nullable) | The last day on which the code is usable. Where null, the code is usable indefinitely. |


### Commodity code indents
The indent of a commodity code represents its depth in the tree. The greater the
indent, the deeper the code.

Indents can evolve separately from commodity codes and have their own validity
dates, and so have their own table. The validity date represents the time that
this commodity code spends at a certain depth in the tree. Note that if the
parent of a commodity code changes but the code stays at the same depth, this
does not represent a new indent and the existing one will not change.

Note also that unlike commodity codes, indents do not have an end date – they
are valid until the start date of the next indent for that commodity.

| Field               | Data type | Comment                                      |
|---------------------|-----------|----------------------------------------------|
| Commodity code SID  | int       | The SID of the commodity code being indented |
| Indent              | int       | The indent value                             |
| Validity start date | date      | The first day on which the code is usable    |

### Resolving parents
Given the above schemas, the parent of a commodity code at a given date is
defined as the commodity code with:

* An indent equal to 1 less
* A code less than, or if equal a suffix less than
* Validity dates on code and indent that contain the given date
* A position latest in the commodity code list when sorting by code and suffix

So in the diagram above, 0101 29 10 00 exists at indent 3, and hence is a child
of 0101 29 00 00 at indent 2. And 0101 21 00 00 with suffix 10 is the parent of
0101 21 00 00 with suffix 80, because although the codes are the same the
suffixes are different and 10 is less than 80.

Note that for legacy reasons, the top two levels of the hierarchy (so codes with
eight trailing zeroes, and codes with 6 trailing zeroes) both have indents of 0
but still exist in parent/child relationship: 0100 00 00 00 is the parent of
0101 00 00 00.

## Challenge
Your challenge is to implement the algorithm that can process data in these two
tables to output a table of the commodity codes alongside their parents. The
algorithm should take as an input a date on which to resolve the parents.

There is an SQLite database available populated with sample data. Your solution
should use SQL and/or Python to read from this database. Please consider
performance when choosing your technology.

The output table should contain:

| Field               | Data type | Comment                               |
|---------------------|-----------|---------------------------------------|
| SID                 | int       | From commodity code                   |
| Code                | char(10)  | From commodity code                   |
| Suffix              | char(2)   | From commodity code                   |
| Description         | text      | From commodity code                   |
| Validity start date | date      | From commodity code                   |
| Validity end date   | date      | From commodity code                   |
| Parent SID          | int       | The SID of the parent commodity code  |
| Parent code         | char(10)  | The code of the parent commodity code |


The output should only contain commodity codes that are valid on the specified
date, and be ordered by commodity code and suffix. If a code does not have a
parent (because it is at the top of the tree) the parent fields should be NULL.

To help verify your solution, the correct output for the algorithm for the date
2021-01-01 is available in a spreadsheet. You can also use
[the Online Tariff](https://www.trade-tariff.service.gov.uk/sections) to look at
specific codes on specific dates and see what the correct parent is.
