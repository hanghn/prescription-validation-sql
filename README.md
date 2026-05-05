# Prescription Validation System (MySQL)

A MySQL implementation of a prescription validation engine that enforces three classes of clinical safety rules at the database layer before a prescription is ever written to the patient record:

1. **Pediatric safety** — block medications not approved for children under 12.
2. **Pregnancy safety** — block medications not safe for pregnant patients.
3. **Drug-drug interactions** — block prescriptions that would conflict with anything the patient is currently taking.

The system also reacts automatically to changes in patient state (e.g., pregnancy status flipping) and cleans up downstream records to keep the data consistent.

---

## Project context & attribution

This started as a course assignment. To be clear about what was provided vs. what I built:

**Provided as scaffolding:**
- The database schema and seed data (`schema.sql`) — 8 tables with relationships and sample patients, doctors, medications, and known drug-drug interactions.
- The high-level requirements: which clinical safety rules to enforce, and the test cases at the bottom of `prescribe.sql` used to validate correctness.

**My contribution:**
- The full `prescribe` stored procedure — variable declarations, the three sequential validation checks, the cursor-based interaction lookup, and `SIGNAL SQLSTATE` error propagation.
- The `patient_after_update_pregnant` trigger — both the prenatal-recommendation insert and the cross-table `DELETE … JOIN` cleanup of unsafe prescriptions.
- All design decisions documented below: when to use a procedure vs. a trigger vs. a cursor, how to structure the error messaging, and the tradeoff analysis between database-layer and application-layer logic.

The interesting work was the design judgment, not the schema setup.

---

## Why this project

The interesting design question isn't "can you write SQL?" — it's **where should each kind of logic live?** Validation rules that must always run regardless of caller belong at the database layer; rules that change frequently belong in the application layer. This project is a study in making that tradeoff deliberately, using the right SQL construct for each kind of rule.

---

## Schema

8 tables with foreign-key relationships across patients, doctors, medications, prescriptions, and known drug-drug interactions:

```
specialty ──< doctor ──< diagnosis >── disease
                │              │
                │              └── patient ──< recommendation
                │                       │
                │                       └──< prescription >── medication
                │                                                  │
                └────────────────────────────────────────────< prescription
                                                                   │
                                              interaction (medication_1, medication_2)
```

Key design choices in the schema:
- **`interaction`** stores both `(A, B)` and `(B, A)` rows for every drug pair, so symmetry is enforced by the data, not by query logic.
- **`patient.is_pregnant`** is a tinyint flag that drives a downstream trigger.
- **`medication`** carries the safety flags (`take_under_12`, `take_if_pregnant`) and dosing info as columns so validation can be a pure SQL check.

---

## What's in this repo

| File | Purpose |
|---|---|
| `schema.sql` | Creates the `ade` database, defines all 8 tables, and seeds them with test data (patients, doctors, medications, known interactions). |
| `prescribe.sql` | The validation engine: a stored procedure for write-time rule enforcement, a trigger for reactive cleanup, and a test harness covering happy-path and rule-violation cases. |
| `writeup.pdf` | Project writeup with design notes and test results. |

---

## How to run

Requires MySQL 8.0+.

```bash
mysql -u root -p < schema.sql
mysql -u root -p < prescribe.sql
```

The bottom of `prescribe.sql` includes a test harness that:
- Inserts 4 valid prescriptions (should succeed)
- Attempts 3 prescriptions that violate each rule class (should each throw the correct error)
- Flips a patient's pregnancy status to verify the trigger fires correctly in both directions

---

## Design decisions — when to use which SQL construct

This was the most interesting part of the project. Different parts of the problem called for different tools:

### Stored procedure → write-time validation
`prescribe(patient_name, doctor_name, medication_name, ppd)` wraps the validation logic. The procedure pulls the patient's age, pregnancy status, and the medication's safety flags into local variables, runs each check in sequence, and either inserts the prescription or raises a typed error. This keeps the validation atomic — there's no window where a bad prescription can be written by skipping a layer.

### `SIGNAL SQLSTATE` → typed error propagation
Each validation failure raises `SQLSTATE '45000'` with a specific human-readable message naming exactly what failed (which drug, which patient, which rule). This lets the calling application handle errors structurally instead of parsing strings or silently failing.

### Cursor → identifying *which* row failed
For drug-drug interaction checking, a cursor walks the patient's existing prescriptions and checks each one against the `interaction` table. A pure set-based query could detect *whether* there's a conflict, but the cursor lets the error message name the specific drug that's already on the patient's record.

> **In hindsight:** this could be done set-based too with a `JOIN ... LIMIT 1` returning the conflicting drug name. The cursor was a deliberate choice for clarity, but a set-based version would be more efficient at scale.

### Trigger → reactive cleanup on state change
An `AFTER UPDATE` trigger on `patient` watches for pregnancy status flips:
- **Becomes pregnant** → inserts a prenatal vitamin recommendation, then runs `DELETE p FROM prescription p JOIN medication m ON p.medication_id = m.medication_id WHERE p.patient_id = NEW.patient_id AND m.take_if_pregnant = FALSE` to remove any prescriptions that are no longer safe.
- **No longer pregnant** → removes the prenatal vitamin recommendation.

The trigger is the right tool here because the cleanup must happen *no matter who* updates the patient row — application code, manual SQL, an admin tool. The database guarantees it.

### `DELETE ... JOIN` → filtered cascading delete
The pregnancy cleanup needs to delete prescriptions filtered by a column on a *different* table (`medication.take_if_pregnant`). A plain `DELETE FROM prescription WHERE ...` can't see across tables, so the join is required.

---

## Testing approach

The test harness runs three categories of cases:

| Category | Cases | Expected outcome |
|---|---|---|
| Happy path | 4 valid prescriptions across different patients/doctors | All 4 insert successfully |
| Rule violations | Pregnancy + pediatric + interaction (one each) | Each throws the correct typed error and inserts nothing |
| Trigger correctness | Pregnancy status flipped true → false on a patient with an unsafe prescription | Recommendation appears, unsafe prescription is deleted, then recommendation is removed when pregnancy ends |

Tests are run by querying `recommendation` and `prescription` after each step to verify state changes match expectations.

---

## What I'd improve

- **Refactor the interaction check to set-based SQL.** The cursor was useful for the named-error message, but a `JOIN ... LIMIT 1` would scale better.
- **Add dose-based validation.** The schema has `mg_per_pill` and `max_mg_per_10kg` columns, plus patient `weight`, but I didn't get to wiring up a max-dosage check.
- **Be more deliberate about what stays in the DB vs. moves to the application.** The pregnancy cleanup trigger is the right call for the DB layer (correctness-critical, multi-caller). The dosing validation arguably belongs in the application layer where it's easier to test and version.

---

## Tech stack

- **MySQL 8.0** — stored procedures, triggers, cursors, `SIGNAL SQLSTATE`, multi-table `DELETE ... JOIN`
