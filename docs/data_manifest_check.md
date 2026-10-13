# Data manifest check: the extracts on disk against docs/data_manifest.csv

Run of script 03 on 13 October 2026. Every line of the manifest of record is recomputed for the files
on disk; PASS means identical. A DIFF on a checksum with PASS on every count means the bytes differ but the
content does not (for instance an unsorted file); a DIFF on a fiscal year's rows or sums says where a later
pull differs from the extracts the results of record rest on.

| File | PASS | DIFF | NEW | MISSING |
|---|---|---|---|---|
| ccm_link.csv | 5 | 0 | 0 | 0 |
| company.csv | 3 | 0 | 0 | 0 |
| crsp_msf_december.csv | 113 | 0 | 0 | 0 |
| funda_1969_2025.csv | 402 | 0 | 0 | 0 |
| funda_footnotes.csv | 63 | 0 | 0 | 0 |

Every line PASSES: the extracts on disk are the extracts of record.
