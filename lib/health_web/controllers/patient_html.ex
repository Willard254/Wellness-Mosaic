defmodule HealthWeb.PatientHTML do
    use HealthWeb,  :html

    embed_templates "patient_html/*"

    def calculate_age(current_patient, today \\ Date.utc_today()) do
        today.year - current_patient.year
    end    

    def calculate_bmi(weight, height) do
        bmi = (weight / (height * height))
        bmi
    end
end