# Sample construction: the paper's screens in order, with the count after each

Frank and Goyal (2003), Section 3, applied to Compustat fundamentals for fiscal years 1971 to 2025.
The CRSP/Compustat link (step 9) is the brief's instruction, not the paper's; the unlinked firm-years
stay in the panel with `ccm_linked = FALSE`, so the all-Compustat population (linked and unlinked) is reported beside the main sample.

| Step | Screen | Firm-years | Firms |
|---|---|---|---|
| 1 | Compustat industrial, standard, domestic, consolidated; fiscal years 1971 to 2025 | 554,977 | 46,528 |
| 2 | one row per firm and fiscal year (later fiscal year end kept) | 554,964 | 46,528 |
| 3 | financial firms (SIC 6000 to 6999) and regulated utilities (4900 to 4999) excluded | 378,900 | 30,417 |
| 4 | firm-years with Compustat footnote code AB (major merger) excluded | 378,308 | 30,416 |
| 5 | missing book value of total assets excluded | 358,059 | 30,378 |
| 6 | cash-flow format codes 4, 5 and 6 excluded | 354,633 | 30,303 |
| 7 | incorporated outside the United States excluded (the paper's Canadian file, format code 5, and the other foreign filers the 2001 file did not hold) | 279,958 | 23,644 |
| 8 | no cash-flow format code (no funds-flow statement, so no flow variable can be built) excluded | 276,168 | 22,994 |
| 9 | main sample: a valid CRSP/Compustat link at the fiscal year end (the Compustat-only population stays in the file) | 201,890 | 18,253 |

Cells recoded to zero (the paper's rule): 38 items, 2,403,174 cells in all; `data/processed/recoding_counts.csv`.
Trimming at 0.5 per cent in each tail is applied by each table and figure to the sample it covers (population and window); what each removed is in `data/processed/trimming_counts.csv` (scripts 04 to 06).
