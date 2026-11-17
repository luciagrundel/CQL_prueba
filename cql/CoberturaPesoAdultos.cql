library CoberturaPesoAdultos version '1.0.2'

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

// Evaluar la fecha en CQL evita que el optimizador la convierta en una
// busqueda por effective (sin SearchParameter resoluble en este motor).
define function "EnPeriodo"(fecha FHIR.dateTime):
  fecha.value during "Measurement Period"

// Esta primera version admite effectiveDateTime, no effectivePeriod.
// Una fecha ausente o fuera del periodo no cumple el criterio.
define "PesosFinalesEnPeriodo":
  [Observation] O
    where O.status.value = 'final'
      and exists(O.code.coding C
        where C.system.value = 'http://loinc.org'
          and C.code.value = '29463-7')
      and "EnPeriodo"(O.effective as FHIR.dateTime)

define "Numerador":
  "Denominador" and exists("PesosFinalesEnPeriodo")
