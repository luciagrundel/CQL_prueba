library CoberturaPesoAdultos version '1.0.0'

using FHIR version '4.0.1'

codesystem "LOINC": 'http://loinc.org'
code "Peso corporal": '29463-7' from "LOINC"

// El motor de Measure suministra este parametro desde periodStart/periodEnd.
parameter "Measurement Period" Interval<DateTime>

context Patient

// Sin fecha de nacimiento no se confirma la elegibilidad.
define "PoblacionInicial":
  Coalesce(
    (years between Patient.birthDate.value and
      date from start of "Measurement Period") >= 18,
    false
  )

define "Denominador":
  "PoblacionInicial"

// Esta primera version admite effectiveDateTime, no effectivePeriod.
// Una fecha ausente o fuera del periodo no cumple el criterio.
define "PesosFinalesEnPeriodo":
  [Observation: "Peso corporal"] O
    where O.status.value = 'final'
      and (O.effective as FHIR.dateTime).value during "Measurement Period"

define "Numerador":
  "Denominador" and exists("PesosFinalesEnPeriodo")
