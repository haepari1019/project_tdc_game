extends RefCounted
## DBP-DEMO-001 §3 run phases (string ids, spec 1:1).

const ENTRY := "Entry"
const ADVANCE := "Advance"
const OBJECTIVE := "Objective"
const ADVANCE_EXTRACTION := "AdvanceExtraction"
const EXTRACTION := "Extraction"

const SEQUENCE: Array[String] = [
	ENTRY,
	ADVANCE,
	OBJECTIVE,
	ADVANCE_EXTRACTION,
	EXTRACTION,
]
