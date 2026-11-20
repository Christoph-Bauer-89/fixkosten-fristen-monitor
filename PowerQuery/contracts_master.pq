// Power Query (M): Abfrage "contracts_master"
// Lädt die Vertrags-CSV, typisiert die Spalten mit deutschem Gebietsschema
// und berechnet das nächste rollierende Kündigungsdatum.
// Vor der Nutzung den Pfad in "Quelle" auf die eigene CSV-Datei setzen.

let
    // 1. Daten aus der CSV-Datei laden
    Quelle = Csv.Document(
        File.Contents("C:\Pfad\zu\Data\contracts_demo.csv"),
        [Delimiter = ";", Columns = 12, Encoding = 65001, QuoteStyle = QuoteStyle.None]
    ),

    // 2. Erste Zeile als Spaltenüberschriften verwenden
    #"Höher gestufte Header" = Table.PromoteHeaders(Quelle, [PromoteAllScalars = true]),

    // 3. Datentypen mit deutschem Gebietsschema ("de-DE") definieren
    #"Geänderter Typ" = Table.TransformColumnTypes(#"Höher gestufte Header", {
        {"Rechnungs_oder_Startdatum", type date},
        {"Ablauf_oder_Enddatum", type date},
        {"Spaetestes_Kuendigungsdatum", type date},
        {"Kuendigungsfrist_Monate", Int64.Type},
        {"Betrag_EUR", type number}
    }, "de-DE"),

    // 4. Rollierende Logik: Liegt das späteste Kündigungsdatum in der Vergangenheit,
    //    wird es je nach Zahlungsturnus so lange weitergeschoben, bis es in der Zukunft liegt.
    HeutigesDatum = DateTime.Date(DateTime.LocalNow()),
    #"Rollierendes Kündigungsdatum hinzugefügt" = Table.AddColumn(#"Geänderter Typ", "Rollierendes_Kuendigungsdatum", each
        if [Spaetestes_Kuendigungsdatum] = null then null else
        let
            OriginalDatum = [Spaetestes_Kuendigungsdatum],
            Turnus = [Zahlungsturnus],

            BerechneZukunft = (AktuellesDatum as date) as date =>
                if AktuellesDatum >= HeutigesDatum then AktuellesDatum
                else
                    if Turnus = "Jährlich" then @BerechneZukunft(Date.AddYears(AktuellesDatum, 1))
                    else if Turnus = "Monatlich" then @BerechneZukunft(Date.AddMonths(AktuellesDatum, 1))
                    else if Turnus = "Quartalsweise" then @BerechneZukunft(Date.AddMonths(AktuellesDatum, 3))
                    else AktuellesDatum
        in
            BerechneZukunft(OriginalDatum),
        type date
    )
in
    #"Rollierendes Kündigungsdatum hinzugefügt"
