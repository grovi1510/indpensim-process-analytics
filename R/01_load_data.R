# 01_load_data.R
# Load process variables from IndPenSim; Raman columns are skipped.
# Data: IndPenSim (simulated), Goldrick et al., Mendeley Data, DOI 10.17632/pdnjz7zz5x.2
#
# Note: the raw header has 2239 names but rows have 2237 values. Header names
# 34-36 are one column (PAT_ref) split on commas, so names from 34 onward are
# shifted. We read without the header and set names manually.

library(data.table)

f   <- "data/raw/100_Batches_IndPenSim_V3.csv"
hdr <- suppressWarnings(names(fread(f, nrows = 0)))  # header row is known to be malformed (see note)

proc <- fread(f, select = 1:37, skip = 1, header = FALSE)
setnames(proc, c(hdr[1:33], "PAT_ref", hdr[37:39]))

# Checks: confirm the column mapping is right
print(dim(proc))
print(table(proc$PAT_ref, useNA = "ifany"))        # expect a few small codes
print(uniqueN(proc$`Batch ID`))                    # expect 100
print(range(proc$`Batch ID`))                      # expect 1 to 100
print(table(proc$`Fault flag`, useNA = "ifany"))   # expect 0/1
print(summary(proc[, .N, by = `Batch ID`]$N))      # rows per batch

saveRDS(proc, "data/processed/process_vars.rds")