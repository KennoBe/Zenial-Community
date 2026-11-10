# ZENIAL Community – UX-Audit und Redesign-Plan

> Status: Plan nach Nutzerkorrekturen überarbeitet. P0 ist abgeschlossen; P1/P2/P3 sind umgesetzt, ihre gemeinsame Clientabnahme ist offen. P2-Harness-Nachweis steht aus.

## Entscheidungen für die erste Redesign-Stufe

- **Finale Navigation:** Heute, Aktivitäten, Quests, Mitspieler, Handwerk, Handel, Meine Charaktere, Einstellungen. Die vorhandene optionale Addon-Manager-Abkürzung bleibt; Glocke und PvP-Hilfe bleiben im Kopf. Normale Workflows haben höchstens eine Unterebene.
- **Charaktere:** Layout A ist gewählt: Charakterauswahl plus gegliedertes Charakterblatt; es ist die **erste vollständige Referenzimplementierung** des neuen Layouts. Alternative B bleibt nur dokumentierter Vergleich. Der Suchbereich heißt „Gespeicherte Gegenstände“ und verwendet ausschließlich vorhandene Suchtreffer aus Taschen-/Bankaufzeichnungen, keinen vollständigen Inhaltsbrowser.
- **Heute:** genau drei Inhaltsbereiche – offene eigene Aufgaben, jetzt relevante Aktivitäten, nächste Termine. Wünsche erscheinen als kompakte Zusammenfassung mit „Bearbeiten“; kein dauerhaft ausgeklapptes Formular und keine zusätzliche große Mitspieler-Rubrik. Bestehende Matchingfunktionen bleiben in den passenden Fachkontexten erreichbar.
- **Bewusst nicht enthalten:** neue fachliche Einstellungen oder Freigaben, Vollinventar-/Bankbrowser (auch nicht aus gespeicherten Daten), Slotraster/Itemaktionen, neue Account-/Exportdaten, automatische Käufe/Einladungen, neue Netzwerklogik, neue dauerhafte Formularspeicherung und eine vorab komplett gebaute UI-Bibliothek. Interne Präferenzen bleiben fachliche Invarianten, keine neuen Schalter.
- **Reihenfolge:** P0 echte Client-Bestandsaufnahme und begrenzte Layoutprobe → P1 minimale Navigation/Aliase/Rückkehr → P3 Charakterreferenz → P2 übrige Navigation/bestehende Settings → P4 Mitspieler → P5a Aktivitätenliste/Detail → P5b eigene Aktivitäten/Termine → P5c Composer/PvP/Heute → P6 Quests → P7 Handwerk → P8 Handel → P9 Integrationen/Dialoge → P10 Gesamtabnahme. IDs bleiben zur Nachverfolgung erhalten; deshalb P3 vor P2.
- **Freigabe:** Dieser Durchlauf ändert nur den Plan. P0 einschließlich wegwerfbarer Client-Layoutprobe erfordert eine ausdrückliche Ausführungsfreigabe. Produktumsetzung startet erst nach dokumentiertem P0-Ergebnis und Freigabe des daraus bestätigten Layout-/Größenrahmens. Jede spätere Phase braucht passende Regressionstests **und** visuelle Forever-Clientabnahme nach G.4; ohne diese Belege bleibt sie offen. Release/Push sind separat freizugeben.
- **Noch durch P0 zu entscheiden:** tatsächlich tragfähige Inhalts-Breakpoints, nutzbare Höhe bei Benutzer-Scale 1,4 und verfügbarer Bildschirm-/UIParent-Größe, sowie Größenkorrekturen für vorhandene Modale. Die Werte in E.4 sind Prüfannahmen, keine bereits im Client bestätigten Zusagen.

## Arbeitsstand und Wiedereinstieg

- Datum: 2026-11-09 (Europe/Berlin)
- Repository: KennoBe/Zenial-Community
- Arbeitsverzeichnis: C:/Users/KennoBe/OneDrive/Dokumente/GitHub/wow/ZenialCommunity
- Branch: docs/ux-redesign-plan
- Geprüfter main-HEAD: 5189cdb51ff0b06317a28810133230571691d1cc
- Version: 5.4.0
- Remote-Prüfung der Erstfassung: git fetch origin main und ls-remote. Bei dieser Revision erneut lokales HEAD, Branch, Status, TOC und git ls-remote --heads origin main abgeglichen: unverändert identischer Commit 5189cdb51ff0b06317a28810133230571691d1cc (5.4.0).
- Ausgangszustand der Erstfassung: sauber; Ausgangszustand dieser Revision: ausschließlich der vorhandene ungetrackte docs-Plan. Änderungen im übergeordneten wow-Repository sind fremd und bleiben unberührt.
- Vorgabe: Keine Lua-/Runtime-Änderungen, keine Commits, kein Push, keine Installation oder Veröffentlichung.
- Dokumentpfad docs/UX-REDESIGN-PLAN.md ist ausdrücklich vom Nutzer vorgegeben und hat Vorrang vor der allgemeinen Ablageregel des wow-Workspace.
- Nächster Einstieg: Zuerst ausdrückliche Nutzerfreigabe prüfen. Ohne Freigabe keine Umsetzung. Danach Branch/HEAD abgleichen und mit F/P0 beginnen; P1 erst nach Client-Machbarkeitsfreigabe. K.3 nach jedem Teilergebnis ergänzen. Sämtliche 13 Pakete (P0, P1–P4, P5a–P5c, P6–P10) sind noch offen; auch die P0-Probe wurde nicht ausgeführt.

### Abgeschlossene Analyse-Checkliste der Erstfassung

- [x] Auftrag und lokale Regeln lesen.
- [x] Aktuellen Remote-main ermitteln und Analyse-Branch erstellen.
- [x] Navigation, alle Seiten/Unteransichten/Dialoge und Laufzeit-Ladereihenfolge erfassen.
- [x] Charaktere, Profile, Quests, Mitspieler und private Sozialfunktionen untersuchen.
- [x] Heute, Aktivitäten, Handwerk und Handel einschließlich Daten-/Aktionspfaden untersuchen.
- [x] Einstellungen, Addon Manager, Companion, Diagnosen und weitere Oberflächen untersuchen.
- [x] Responsive-Mechanismen, Überschreibungen, Datenschutz und technische Grenzen erfassen.
- [x] Aktuelle Primärquellen zu Referenz-Addons vergleichen.
- [x] Vorher-/Nachher-Sitemap und vollständige Funktionszuordnung erstellen.
- [x] Wireframes, zwei Charakterkonzepte und gemeinsames Designsystem erstellen.
- [x] Mindestens zehn User Journeys mit nachvollziehbaren Interaktionszahlen festhalten.
- [x] Abhängige Implementierungsphasen, Regressionstests und Priorisierung ausarbeiten.
- [x] Unabhängige Lesbarkeits-/Umsetzbarkeitsprüfung und lokale Dokumentprüfung abschließen.
- [x] Abschlussdokument für Nutzerprüfung bereitstellen.
- [ ] Ausdrückliche Freigabe zur Implementierung erhalten (ausstehend).

### Checkliste dieser Planrevision

- [x] Aktuellen lokalen und Remote-HEAD, Branch, TOC und Dateistatus erneut prüfen.
- [x] Frühen Entscheidungsabschnitt sowie P0 mit konkreten Client-Screens, Mindestgrößen, Scales und begrenzter Layoutprobe ergänzen.
- [x] P1 auf Navigation/Legacy/Rückkehr begrenzen; P3 als erste vollständige Referenz vor P2 setzen; Primitiven nur bedarfsweise.
- [x] P5 in P5a/P5b/P5c mit eigenen Regressionen und DoD aufteilen; Abhängigkeiten und Prioritäten nachführen.
- [x] Heute auf drei Rubriken und kompakte Wünsche begrenzen; Suchansicht statt Inventar-/Bankbrowser und nur tatsächlich angebotene Settings festlegen.
- [x] E.3.1 für unbekannte/veraltete/gültige Links bei offenen Eingaben sowie G.4 als verpflichtende Clientabnahme je Phase ergänzen.
- [x] Wireframes, 32 Journeys, Scopegrenzen und Querverweise konsolidieren; technische Befunde/Fachverträge/Regressionen erhalten.
- [x] Lesenden Source-/Planabgleich unabhängig gegenprüfen; zwei verbliebene widersprüchliche Sollsätze zu Spielern auf Heute und UTC-Auswahl korrigieren.
- [x] P0 im echten Client ausführen (2026-11-10: Umgebung, Clientmessung, ESC/Chat/Kampf im Client; Größenmatrix als kalibrierte Web-Simulation, siehe K.3).
- [x] P0-Ergebnisse und bestätigten Größen-/Layoutumfang vor Produktumsetzung freigeben (Nutzer, 2026-11-10).

### Statusprotokoll

| Schritt | Status / Ergebnis | Nächste Aktion |
|---|---|---|
| 1 – Basis | main remote verifiziert, neuer Branch angelegt, keine Codeänderung | Quellcode-Audit mit getrennten Zuständigkeiten |
| 2 – Navigation | Elf interne Seiten; sichtbare Reihenfolge 9/10/4/1/2/5 plus optional Addons und Settings. Versteckte Gruppen-/Questhilfe-Tabs bestätigt. | Effektive Handler nach TOC abgleichen |
| 3 – Effektive Aktionen | ActivityDetailsUI überschreibt OpenActivity; gemeinsames Detailmodal bereits vorhanden. Material-Handel-Wechsel löscht temporären Herstellungs-Kontext via CloseDialogs. | Rücksprungvertrag im Zielkonzept festlegen |
| 4 – Zusatzflächen | Netzwerk-/Join-/Katalog-/Diagnose-/Backup-/Companion-/Inbox-/Kartenflächen gelesen; Referenzrecherche begonnen. | Komponenten, Settings-Zuordnung und Responsive-Strategie formulieren |
| 5 – Fachaudit | Zwei getrennte Sol-Audits integriert; kritische Pfade im Source gegengeprüft | Gesamtkonzept konsolidiert |
| 6 – Zielkonzept | Acht Hauptbereiche, vollständige Zuordnung, Wireframes, zwei Charakterkonzepte, gemeinsame UI-Verträge, ursprünglich zehn Phasen und 32 Journeys (Revisionsstand: 13 Pakete) | Native Nachweise erst bei Umsetzung |
| 7 – Baseline | Fünf bestehende Suiten mit Lua51 bestanden; keine Produktcodeänderung | Struktur-/Gitprüfung |
| 8 – Unabhängiger Builder-Check | Ein materieller Payloadkonflikt identifiziert und korrigiert: Stückzahl, Crafts und Trinkgeldtext getrennt; sonst keine wesentlichen offenen Punkte gemeldet | Korrigierten Vertrag dokumentarisch geprüft |
| 9 – Erstfassung abgeschlossen | Plan der Erstfassung lokal gespeichert, uncommittet; Branch-HEAD unverändert | In dieser Revision durch P0-/Referenzreihenfolge präzisiert |
| 10 – Planrevision | Aktueller Source unverändert; P0 und phasenweise Clienttests geplant, P1 reduziert, P3 Referenz, P5a/b/c getrennt; Source-/Scopeabgleich durch Sol lesend geprüft | Dokumentkonsistenz und unveränderte Source prüfen; danach auf P0-Ausführungsfreigabe warten |

## Befundkennzeichnung

- **B (belegt):** aus konkreter Implementierung und Ladereihenfolge nachvollzogen.
- **E (Empfehlung):** UX-/Architekturvorschlag, noch nicht umgesetzt oder freigegeben.
- **V (zu verifizieren):** benötigt tatsächlichen WoW-Forever-Client, Nutzertest oder fehlende externe Evidenz.

Statische Codeanalyse ist kein visueller Ingame-Test. Klickzahlen werden für definierte Ausgangszustände abgeleitet und nicht als gemessene Nutzertestwerte ausgegeben.

## Ziel und verbindliche Grenzen

**Ziel:** Eine zusammenhängende WoW-Anwendung mit verständlichen Aufgabenbereichen und kontextbezogenen Aktionen. Dieser Plan beschreibt den späteren Umbau; alle nachfolgenden Soll-Aussagen sind Empfehlungen, keine bereits bestehende Funktion und keine Umsetzungserlaubnis.

**Architekturentscheidung:** Vorhandene Fachmodule und Adapter bleiben zuständig. Ein gemeinsamer UI-Router, eine gemeinsame Listen-/Detailaufteilung und kleine spezialisierte Ansichten ersetzen schrittweise versteckte Navigation und nachträgliche Umbauten. P1 umfasst ausschließlich Navigations-/Legacy-/Rückkehrschutz; wiederverwendbare Layoutbausteine entstehen erst aus der Charakterreferenz P3 und einem nachgewiesenen weiteren Bedarf. Keine Neuentwicklung des Netzwerks und kein neues Accountmodell.

**Technik:** Lua, WoW Frames, TOC Interface 16001, vorhandene Theme-/Adapter-Fallbacks; kein Webfrontend im Addon, kein zusätzliches UI-Framework. Clientkompatibilität wird am Forever-Client geprüft, nicht aus Retail-Screenshots abgeleitet.

**Spezifikation:** Vollständiger Nutzerauftrag „ZENIAL Community – Vollständige UX/UI-Analyse und Redesign-Plan“, hier durch Audit A, Navigation B, Wireframes C, Designsystem D, Architektur E, Phasen F, Tests G und Priorisierung H abgedeckt.

- Nur UI und zugehöriger Navigationszustand ändern; Geschäftslogik, Defaults, Freigaben und technische Grenzen erhalten.
- Kein automatisches Veröffentlichen, Einladen, Kaufen, Anflüstern, Importieren oder Löschen beim Navigieren.
- Hauptnavigation sichtbar; normale Aufgaben höchstens eine Unterebene. Detailauswahl, Filteraufklappen und Bestätigungen sind Aktionen, keine weiteren Menüebenen.
- Vorhandene Slash-Commands, Benachrichtigungsziele, Kartenintegration und externe Addon-Einstiege erhalten.
- Private Accountdaten nicht in öffentliche Profile/Presence/Netzwerkpakete übernehmen. Der vorhandene optionale Companion-Export ist ein gesonderter, ausdrücklich gekennzeichneter Datenweg; „privat“ bedeutet nicht automatisch „vom Companion ausgeschlossen“.
- Keine Datenmigration nur wegen einer anderen Darstellung. Bestehende Main-/Twink-Scopes, Importregeln, Speicherlimits und Read-only-Fälle bleiben erhalten.

## A. UX-Audit – belegter Istzustand

### A.1 Methode und effektive Oberfläche

Untersucht werden Konstruktion, TOC-Reihenfolge, Handler, Route, Backendfunktion und Rückkehrweg. Dateinamen/Zeilen beziehen sich auf den oben fixierten Commit; ein späterer Ausführender muss bei abweichendem HEAD neu abgleichen. B bezeichnet Codebefunde, E Empfehlungen, V offene Laufzeitprüfung. Die Texte „gedrängt“, „ruhiger“ oder „besser auffindbar“ sind UX-Bewertungen und keine gemessenen Nutzerbefunde.

**B:** `UX.lua:19` definiert elf Seitennamen. `UXCreate.lua:184` erzeugt die Seiten; `UXLayout.lua:18` zeigt nur Heute, Aktivitäten, Quests, Mitspieler, Handwerk und Handel sowie unten Einstellungen und optional Addon Manager. Gruppen, Profil und Verlauf bleiben intern erreichbar. `UIState.lua:42,53` übersetzt alte Seiten teilweise in Heute/Aktivitäten/Einstellungen. Die Navigation ist daher weder allein aus den Namen noch aus gespeicherten Routen abzulesen.

**B:** `CommunityHomeUI.lua:317–324` versteckt alle sieben Gruppen-Tabs, drei Questhilfe-Tabs und den Materialplanungs-Tab. Das erhält Code, ersetzt aber erkennbare Einstiege durch Board-, Kontext- und Rücksprungaktionen. **E:** Aufgabenbereiche sichtbar machen, alte Routennamen als kompatible Aliase bewahren.

**B:** `ActivityDetailsUI.lua:84` ersetzt das frühere `U.OpenActivity` aus `CommunityHomeUI.lua:57`. Der effektive Weg endet im gemeinsamen Modal für LIVE/QUEST/EVENT/PVP. **E:** Dieses vorhandene gemeinsame Aktionsmodell als Basis verwenden, nicht vier neue Detailarchitekturen bauen. Die Quelle/Art bestimmt weiterhin Fachregeln und verfügbare Aktionen.

### A.2 Einstellungen und Zusatzflächen

| Ansicht / Beleg | Öffnen und Herkunft | Daten / Aktionen / weitere Wege | Befund und Priorität | Konkrete Neugestaltung / Größenrisiko |
|---|---|---|---|---|
| Einstellungen – `CommunityHomeUI.lua:298`, `CreateCommunityHome` | Sichtbarer Hauptpunkt, intern Seite 11 | Sieben Links: Profil, Charaktere, Darstellung, Verbindung/Privatsphäre, Addons, Verlauf, Companion; Manager-Navigationscheckbox; Kategorienverwaltung wird später ergänzt | B: hauptsächlich Linksammlung, Facharbeit und Einstellungen vermischt. E: hoch | E: echte Einstellungsgruppen mit direkten vorhandenen Reglern; Charaktere ins Hauptmenü, Profil in persönliche Charakteransicht, Verlauf kontextbezogen. Ein Inhalts-Scrollbereich statt wachsender Buttonspalten |
| Öffentliches Profil – `UXPageProfile.lua:10`, `createProfilePage`; `UXViews.lua:83` | Einstellungen → Charakterprofil; Profil-Tabs erlauben Wechsel zu Charakteren/Darstellung/Verbindung | Anzeigename, bevorzugte Rolle, Notiz, Vorschau, Speichern→`U.Publish`, Profil bei Mitspielern zeigen | B: öffentliche Bearbeitung und private Daten liegen unter gleichem Profil-Dach; E: hoch | E: „Öffentliches Profil des aktuellen Charakters“ eindeutig markieren; nur aktuell eingeloggten Charakter bearbeiten. Öffentliche Freigaben separat erläutern. Bestehende 32-/64-Zeichenvalidierung erhalten |
| Darstellung – `UXPageProfile.lua:80` | Einstellungen → Darstellung / Profil-Tab | Standardgröße 1060×690, Position/Skalierung zurücksetzen; aktueller Rahmen 900×610 bis 1280×860 | B: Text und Rücksetzbuttons, kein allgemeiner Settingskatalog; E: mittel | E: direkt in Einstellungen/Darstellung; kein neuer Skalierungsregler ohne gesonderte Entscheidung. Zurücksetzen darf sonstige Einstellungen nicht ändern |
| Verbindung/Privatsphäre – `UXPageProfile.lua:97`, `NetworkSetup.UserSummary:98` | Einstellungen → Verbindung und Datenschutz; Profil-Tab | Sichtbares Profil, Berufe/Rezepte teilen via `Z.SetPreference`; Status, Aktualisieren, technische Details, Verbindungsdialog | B: harmlose Statusanzeige und Freigaben neben technischen Einstiegen; E: hoch | E: klar beschriftete vorhandene Freigaben in Datenschutz; kurzer Verbindungsstatus mit gezielter Aktion; Technik separat |
| Verbindungsübersicht – `NetworkSetup.lua:114,137` | `NetworkSetup.Show` wenn kein Beitritt fehlt; Profil/Verbindung; `/zenial setup`, `bnet`, `lounge` | CommunityDirectory/BattleNetTransport-Status; Scan/Test, Einladungslink, Technik | B: zweites Fenster zusätzlich zur Profil-Verbindungsansicht; E: mittel | E: gleicher Statusbaustein in Einstellungen/Community. Eigenständiger kompatibler Einstieg darf weiter denselben Inhalt anzeigen. Aktuelle Fokusregeln erhalten |
| Community-Beitritt – `NetworkSetup.lua:231,299` | Join-Banner; automatischer Hinweis bei fehlender Mitgliedschaft nach Bereitschaftsprüfung; Setup | Drei Schritte Link auswählen/kopieren, Blizzard-Beitritt öffnen, einfügen; Companion-Hinweis und optionaler Export | B: außerhalb Hauptfenster, Höhe 590, externe Benutzerinteraktion nötig; E: hoch | E: abgesetzter geführter Ausnahmeablauf mit Rückkehr zum Ausgang; Kopieren/Einfügen weiter manuell. Kein Fokusdiebstahl, kein automatischer Join; Combat-Sperre und native Fenster erhalten |
| Einladungsliste – `NetworkSetup.lua:159,165` | Verbindungsübersicht/erweiterte Netzwerkseite → Einladungslinks | zugewiesene Lounges/Bootstrap, vor/zurück, Text auswählen | B: separates 760×200-Fenster; E: niedrig | E: kleines Copy-Detail im Verbindungsbereich, langer Link bleibt auswählbar; keine neue Clipboard-API voraussetzen |
| Erweiterte Netzwerkeinrichtung – `NetworkSetup.lua:185,270` | Technische Details in Verbindungsübersicht oder `/zenial setup advanced` | Zuweisung, nächste Gruppenpaarung, Lounge-Auswahl, Einladung hinzufügen/aktualisieren, Katalog, BNet-/Whisper-Test, Scan, Diagnose, WoW-Beitritt | B: Betreiber- und Diagnosetätigkeiten zusammen mit normalem Setup; E: mittel | E: Einstellungen/Erweitert als deutlich gekennzeichneter Technikbereich. Keine neuen Operatorrechte oder Einschränkungen; existierende Aktionen unverändert weiterleiten |
| Gruppenkatalog – `NetworkSetup.lua:143` | Erweiterte Einrichtung → Katalog kopieren/importieren | `ExportCatalog`, auswählbarer Text, `ImportCatalog`, Erfolg/Validierungsfehler | B: Import ändert Netzwerk-Konfiguration; E: mittel | E: separater Importdialog bleibt sinnvoll, mit Herkunft und Wirkung, unveränderte Validierung. Nicht beim Anzeigen importieren |
| Diagnosebericht – `UI.lua:60,84`, `Diagnostics.lua:100,112` | Profil/Verbindung → technische Details; Netzwerk-Technik; Slash-Aliase `network/netzwerk/debug/diagnose/diagnostics/logs` | Bericht markieren/aktualisieren, lokale Backups öffnen; Scrolltext, keine Versandaktion | B: nützliche zentrale Diagnose schon vorhanden; E: niedrig | E: weiterverwenden, direkt Einstellungen/Diagnose; kompakte Zusammenfassung vor Rohbericht; nichts automatisch senden |
| Backupverwaltung – `UI.lua:68,125`, `Diagnostics.lua:75,86` | Diagnose → Backups | ForeverLive-/Charaktermigration-/Merge-Backups, Größe/Alter, zweiter Löschklick, Abbrechen | B: destruktive Aktion hat zweite Bestätigung; E: mittel | E: vorhandene Zweitbestätigung erhalten; klare Benennung, nicht mit Charakter löschen verwechseln. Keine neue Wiederherstellungsfunktion erfinden |
| Companion-Setup/Einführung – `CompanionUI.lua:26,62,72,82` | Einstellungen → Companion, `/zenial companion`, optional Join/automatische Einführung nach Bereitschaft, nur außerhalb Kampf | Export an/aus via `SetExportEnabled`, Questflächen via `SetQuestAreasEnabled`, Downloadlink, Transport-/Flush-/Pixelstatus | B: optionaler Export umfasst auch eingehenden Chat und private Notizen/Planung; technische Zähler dominieren Status; E: hoch | E: Einstellungen/Integrationen → Companion mit „Aus / Aktiv / Angehalten / Daten veraltet“, daneben expliziter Exportumfang; technische Zähler aufklappbar. Keine neue Teilfreigabe suggerieren, vorhandener Export ist alles oder aus. Eigenständige Einführung erhalten |
| Benachrichtigungszentrale – `NotificationInboxUI.lua:21`, `RefreshNotificationInbox:3` | Glocke im Fensterkopf, auf jeder Seite | `Notifications.Recent`, letzte maximal 50, Klick→`OpenUpdate` bzw. Laufzeitcallback; Öffnen ruft `ReadRecent` auf | B: Öffnen liest Recent-Marker, nicht automatisch alle fachlichen Unread-Tokens; einige Laufzeitcallbacks überleben Reload nicht; E: mittel | E: Liste mit Titel, Zeit, kurzer Meldung, eindeutigem Ziel; nicht mehr existierendes Ziel erklären; zwei Read-Ebenen nicht versehentlich verschmelzen |
| Toaster / PvP-/Todes-/Bewerbungs-/Versionshinweise – `NoticeUI.lua:20`, `UXNotices.lua:130–371`, `UpdateNotice.lua:44` | Ereignisse, global außerhalb Hauptfenster | Höchstens drei sichtbare gestapelte Karten; Klick→passender Fachkontext, Schließen ändert fachliches Unread nicht | B: eigener Oberflächenbereich; E: mittel | E: ein Status-/Meldungsvokabular, dieselben Deep Links wie Glocke; keine Aktion allein durch Hover/Empfang auslösen; kleine Bildschirme prüfen |
| Discord – `UI.lua:44` | Fensterkopf | Linkfeld markieren/kopieren, Schließen/ESC | B: statischer Kopierdialog; E: niedrig | E: bestehendes Verhalten behalten, lange Links/DE/EN prüfen; kein Browseraufruf nötig |
| Unsupported-Beta-Hinweis – `NetworkSetup.lua:17,21` | Produkterkennung `agentUID == wow_classic_beta`; blockiert Setup-/Companion-Weg | Release-Hinweis/Discord, Bestätigung per Schließen | B: technische Sonderbedingung, kein normaler Menübereich; E: niedrig | E: Ausnahmefläche erhalten; Inhalt vor nächster Veröffentlichung auf Zeitbezug prüfen, keine Kompatibilität durch Redesign versprechen |
| Community-Kartenoverlay – `CommunityMap.lua:121,151–239`, `CommunityMap.xml` | Blizzard-Weltkarte; Tracking-Menü „Community members“ / „My guild only“ falls API vorhanden | aktuelle Positionen, Klassenfarbe, Alter, überlappende Spieler-Tooltips, PvP-Todespunkte; `SetShown`, `SetGuildOnly` | B: Pins sind absichtlich reine Hoverflächen; Klicks gehen an Weltkarte. Keine versteckte Profilaktion behaupten. E: niedrig | E: bestehende Kartensteuerung bleibt; Einstellungsbeschreibung verweist auf Tracking-Menü; kein neues geschütztes Pinverhalten |
| Minimap-Hub / Addon Compartment – `Launcher.lua`, `LauncherSpec.lua:4,14`, `Main.lua:606` | ZENIAL-Icon links Community, rechts gemeinsamer Hub; Compartment-Callback | öffnet bestehende Hauptansicht bzw. Addon-Einstieg, Unread-Status; Launcher-spezifische Hide/Show-/Wizardaktionen | B: weitere Einstiegsebene außerhalb Community; E: niedrig | E: bestehende `openMain`/`openSettings`/`OpenAddonManager`-Verträge erhalten. Keine Launcher-Duplikate und keine Umbenennung anderer Addons |

### A.3 Addon Manager: vollständiger Vertrag

**B:** `UX.lua:208` enthält sechs Katalogeinträge: Crit, GunSound, DevLogger, ClassFrames, Watch und Utility. `UXPageProfile.lua:148` erzeugt horizontale Auswahlbuttons und `addonHost`. `UXAddons.lua:21` unterscheidet missing, disabled, unavailable, loading, reload, ready und legacy. Nur installierte Einträge bekommen sichtbare Tabs (`RefreshAddonAvailability:56`); bei sechs Einträgen teilen sie 856 logische Pixel, Versionen stehen im Tabtext. Bei ready verschwinden Status und Beschreibung (`RefreshAddonManager:133`). `apiVersion == 1` plus `CreatePanel(parent)` ist der Einbettungsvertrag. Ein Frame/Refresh-Paar wird einmal erzeugt und gecacht; Erzeugung/Refresh sind mit `pcall` geschützt. Legacy nutzt vorhandenen Slash-Handler; deaktivierte Addons werden nicht automatisch aktiviert.

**B:** Ohne installierten Katalogeintrag ist der Settings-Button deaktiviert und die Hauptnavigation ausgeblendet. Die Routine kennt missing, aber ein fehlendes Addon ist über dessen eigenen Tab nicht auswählbar. **E:** Installierte Addons als ruhige vertikale Liste; Name, Version und Status in eigenen Feldern, Beschreibung beim Auswählen. Ergänzend vorhandene Katalogeinträge unter „Weitere ZENIAL-Addons“ mit „Nicht installiert“ erklären. Keine Installations-/Aktivierungsfunktion hinzufügen. Ein Dialoghost verwendet dieselben Provider oder den unveränderten externen Fallback. Der Manager bekommt eine sichtbare Rückkehr zu Einstellungen/Integrationen und behält die bestehende optionale Hauptmenü-Abkürzung; diese Checkbox und ihr Default werden nicht still entfernt.

**E:** Liste statt Karten empfohlen: sechs unterschiedlich lange Namen/Versionen, Zustände gut vergleichbar, geringer Platzbedarf. Karten wären lesbar, benötigen aber mehr Fläche ohne zusätzlichen Nutzen. Einbettung ist eine Integrationsgrenze: deren interne Menüs werden nicht umgebaut; normale Community-Workflows haben weiter nur eine Unterebene, eingebundene Fremdoberflächen dürfen ihre eigene Navigation behalten.

**V:** Provider mit eigenem Strata/Scale, fehlender/alter API, Erzeugungsfehler, fehlendem Refresh, sechs installierten Addons und `/reload`-Zustand im echten Client prüfen. Der Plan verändert keine Funktion der sechs eingebundenen Addons.

### A.4 Vorhandene Einstellungen vollständig zuordnen

Die Kategorien ordnen ausschließlich bereits tatsächlich angebotene Einstellungen und Aktionen neu. Ein gespeicherter Wert oder zugelassener Setter allein ist kein UI-Angebot. Interne Gates werden nur dokumentiert/getestet und nicht als neue Regler sichtbar gemacht. Nicht jeder gespeicherte Filter ist eine globale Einstellung; vorhandene Fachkontext-/Weltkarten-/Slashbedienung bleibt dort erhalten.

| Existierender Wert / Besitzer | Heutige Bedienung / Wirkung | Soll-Ort / Erhaltung |
|---|---|---|
| `visible`, `shareProfessions` – `Main.SetPreference:408`, `AccountPreferences.lua:11` | Profil/Verbindung; kontoweit übertragene Präferenz | Datenschutz: ausschließlich vorhandene Controls für sichtbares Profil und Berufe/Rezepte teilen; aktuelle Werte, Validierung und Abbruch alter Netzwerkjobs erhalten |
| `consent`, `autoDiscovery`, `shareGuild`, `shareQuests` – `Core.lua:97`, `Main.lua:409` | Bestehende Fachpräferenzen mit Setter, in der gelesenen Profiloberfläche keine eigenen Regler | Keine neuen UI-Schalter im ersten Redesign. Interne Gates, bestehende Setter und Defaults unverändert erhalten; ihre Sichtbarmachung benötigt eine separate fachliche Prüfung und Freigabe außerhalb dieses Plans |
| Fenster `width/height`, `scale`, `position` – UIState/UXCreate/UXPageProfile | Ziehen/Resize, Standardgröße, Position zurücksetzen; account preferences übertragen teils Darstellung | Darstellung: dieselben zwei Rücksetzaktionen und gespeicherte Geometrie; Wertebereiche 900–1280 / 610–860 und Scale-Limits erhalten, Responsive intern verbessern |
| `showAddonManager` – `UIState.lua:35`, `UXLayout.lua:59` | Settings-Checkbox; Default true, tatsächliche Verfügbarkeit zusätzlich geprüft | Integrationen: optionaler direkter Addon-Manager-Eintrag unverändert |
| `memberGrouping`, `memberStatus`, Klassen-/Berufs-/Sortier-/Kontaktfilter | Mitspieleransicht; teils gespeicherter Navigations-/Ansichtszustand | Bleibt Mitspieler-Schnell-/Erweitertfilter; keine zusätzliche globale Konfigurationsseite |
| `mapMembers`, `mapGuildOnly` – CommunityMap/AccountPreferences | Weltkarten-Tracking-Menü | Darstellung/Community nur als Verweis auf das vorhandene Weltkarten-Tracking-Menü; keine zweite Settingscheckbox; vorhandene Defaults/Scope erhalten |
| `pvpReceive`, `pvpScope` – PvPHelp/AccountPreferences.ApplyViews | PvP-Hilfe empfangen, alle/aktuelle Zone | Bestehende PvP-Seite plus erläuterte Zuordnung unter Benachrichtigungen; ein Setter, keine getrennten widersprüchlichen Werte |
| private Kategorien / Definitionen – SocialCategories | Settings-Verwaltung, Kontaktchips, kombinierter Mitgliederfilter | Mitspieler: „Kategorien verwalten“ öffnet denselben Editor; Settings-Verweis darf als nachvollziehbarer zweiter Einstieg bleiben |
| Companion `enabled`, `questAreasEnabled`, Diagnosepixel – CompanionUI/Main | Setup/Join, Export/Questflächen, `debug on/off` | Integrationen/Companion nur bestehende Export-/Questflächencontrols; Diagnosepixel bleibt Slashbedienung, kein neuer Erweitert-Schalter; Exportumfang und Combat-Pause explizit |
| Minimap-Hub `minimapHidden`, `minimapAngle`, `ZenialMinimapDB` | Gemeinsamer Launcher; gespeicherte Darstellungspräferenz | Bestehender Launcher bleibt Besitzer. Community verweist bei Bedarf darauf; keine zweite Speicherung |
| lokale Charakteraufnahme `SetEnabled/SetInventory` und Diary-Aufnahme `SetEnabled/SetSource` | Übersicht/Diary; zwei getrennte Opt-ins mit vorhandenen Quellen und Defaults | Datenschutz: lokale Aufzeichnung; Kontextlinks bleiben, keine automatische Aktivierung und keine öffentliche Freigabe |
| gespeicherte Unteransichten, Questkategorien, Profil-/Angebotsentwürfe – UIState | pro Charakter; Aktivitätsdialog-Eingaben bewusst nur RAM | Routenzustand/UI, nicht allgemeine Settings; diese Persistenzgrenze erhalten |
| Gruppen-/Handelsvorlagen, Follows, Suchalarme, private Materiallisten | jeweiliger Fachworkflow | bleiben am Fachobjekt; keine Verlagerung als globale Settings |
| Benachrichtigungslog/Unread, Sounds – Notifications/UXNotices/Adapter | fachliche Marker; Sound ist vorhandenes Verhalten, kein umfassender Reglerkatalog | Benachrichtigungen zunächst Erklärung und bestehende PvP-Empfangsoptionen; keine erfundenen Sound-/Kanal-/Ruhezeitregler |
| Diagnose, Backups, Verbindungstests, Operator-Katalog, Reset-API | technische Aktionen; `Z.Reset` ist kein regulärer sichtbarer Menüpunkt | Erweitert/Diagnose nur existierende sichtbare Funktionen übernehmen. `Z.Reset` nicht allein wegen Existenz als neuen „Alles löschen“-Button anbieten |

### A.5 Responsive, Aktualisierung und Überschreibungen

**B – Geometrie:** `UXLayout.lua:90–156` berechnet Scale als Minimum aus verfügbarer Breite/856 und Höhe/500. Unter 1000 Fensterbreite wird Sidebar 124 statt 150 breit; unter 780 Inhaltsbreite kommt `compactContent`. Bei 900×610 ohne Join-Banner bleiben etwa 718×464 für die Seite: Scale ca. 0,839. Das verkleinert auch Schrift. Mit Banner können Höhe und Scanbereiche weiter schrumpfen. `UXCreate.lua:33` setzt Rahmen-Scale aus `Z.db.scale` zusätzlich. Eine große logische Fläche ist also keine Lesbarkeitsgarantie.

**B – Reflow:** `ResponsiveUI.lua:30` registriert bestehende Widgets und löst deren Footer-/Listenbeziehungen einmalig auf. `ApplyResponsiveLayout:67` verändert Breiten und verschiebt Footergruppen. `zenialOwnLayout`, Listen, Mitgliederprofil-Scroll und Kategorienrahmen sind ausgenommen. `AccountOverviewUI.lua:339` ist daher ein eigener Layoutbesitzer. `UXViews.OpenCompactArea:134` blendet Listen/Filter aus und stellt Detailaktionen um; `CloseCompactArea:222` stellt feste Ausgangspositionen wieder her. Das sind pro Bereich eigene Regeln, kein durchgängiges adaptives Raster.

**B – Performance:** Resize coalescing und 10-Hz-Reflow existieren bereits (`UXLayout.lua:160`). `UX.lua:648` virtualisiert und recycelt sichtbare Zeilen, auch variable Höhen. `UXMembers` verwendet revisionierte Member-Snapshots. `Main.lua:681` bündelt Dirty-Refreshes im 0,25-s-Tick; Zeitanzeigen im 1-s-Tick, Housekeeping alle 5 s. `UXLayout.Refresh:382` aktualisiert im Normalfall sichtbare Seiten; offene Dialoge zusätzlich. Das sind zu bewahrende Grundlagen, kein Grund für einen globalen UI-Neuaufbau.

| Definition / nachträglicher Eingriff | Effektiver Besitzer / Risiko | Planentscheidung |
|---|---|---|
| `OpenActivity` in Home und ActivityDetails | ActivityDetails gewinnt laut TOC | Eine Definition; Altaufrufe bleiben Fassade derselben Aktion |
| `OpenPrivateCategories` in UXMembers und Home-Konstruktion | Home überschreibt zur Mitspieler-/Compact-Navigation; alter Popupcode bleibt | Kontaktzuordnung und Definitionsverwaltung getrennt benennen; unbenutzten Code erst nach Aufrufernachweis entfernen |
| Group-/Quest-Editoren und `OpenGroupEditor/OpenQuestEditor/OpenScheduledEditor` | FormLayout baut Geometrie und Verhalten um; vorherige Handler teils gewrappt | Konstruktion gezielt in vorhandenem Modul vereinheitlichen; keine parallele neue Composerlogik |
| `T.Panel/Shell/Button/Style*` Theme→ThemeCommunity | beabsichtigter Skin-Layer, Community später geladen | Bewusstes Theme-Override erhalten, dokumentieren; nicht als Funktionsduplikat entfernen |
| Haupttabs/Untertabs werden erzeugt, später versteckt und Teile reparented | UXCreate→CreateCommunityHome→Zusatzkonstruktoren | Router/Ansichtsregister kennt Sichtbarkeit vorher; keine neue globale Hide-Liste |
| Layout in UXLayout, ResponsiveUI, AccountOverviewUI, FormLayoutUI, PvPHelpUI | unterschiedliche Besitzer; Anchors können sich gegenseitig ersetzen | Pro Bereich genau ein Layoutbesitzer; `zenialOwnLayout` als Migrationsgrenze, gemeinsames Größenmodell |
| `CloseDialogs` löscht `craftOrderContext` (`UXLayout.lua:561`), `OpenMaterialOffer` navigiert Seite (`UXTrade.lua:340`) | geplanter Einkauf kann temporären Fortsetzungszustand verlieren | Navigationskontext von Modalsichtbarkeit trennen; explizites Abbrechen verwirft, Einkaufsausflug bewahrt |

**V:** Keine tatsächliche Überlappung, Lesbarkeitsnote oder Schutzaktionsfreiheit ist durch statischen Code allein bewiesen. Größenmatrix, Kampf-/ESC-Verhalten, DE/EN-Textumbruch und Frame-Strata müssen im Client abgenommen werden.

### A.6 Detailinventar: Heute, Aktivitäten, Planung, PvP, Handwerk und Handel

Die folgenden Tabellen konkretisieren A.1–A.5. U0/U1/U2 in den Auditbefunden bedeuten UX-Schweregrad, nicht Implementierungsphase. Die verbindlichen späteren Pakete heißen P0, P1–P4, P5a–P5c und P6–P10 in F; Priorisierung H verwendet deshalb Schweregrade kritisch/hoch/mittel/niedrig. Wiederholte Routen sind nachgewiesene Mehrfacheinstiege, keine zusätzlichen Sollmenüs.

| Ansicht/Dialog | B: Quelle, Einstieg, Daten und Aktionen | Schwäche / E: Ziel / Priorität |
|---|---|---|
| Heute | `CommunityHomeUI.lua:U.CreateCommunityHome:248`, `U.RefreshCommunityHome:145`, `ActivityBoard.lua:B.Home:104`. Hauptmenü Heute. Bis drei private Wunschkarten, anschließend **eine** scrollende Liste mit Jetzt passend, heute geplant, eigene Aktivitäten heute und passenden Mitspielern. Jede Aktivität direkt ins effektive Detailmodal; Spieler nach Mitspieler mit Vorauswahl/kompaktem Detail. Fuß: gemeinsame Quests, Questgruppen, alle Aktivitäten, Erstellen. Pro Aktivitätssektion maximal 20 Einträge, danach Verweis auf Aktivitäten. | B: keine freien/unpassenden Aktivitäten auf Heute; eigene gespeicherte Offlinebewerbungen für Live/Quest werden in Home ausgeschlossen, Board kann sie dagegen anzeigen. Lange 98/118-Pixel-Aktivitätszeilen und mehrere Überschriften teilen eine Liste. E: genau offene eigene Aufgaben, jetzt relevante Aktivitäten und nächste Termine. Spieler-/Matchingtreffer bleiben im passenden Fachkontext erreichbar; keine zusätzliche Dashboardrubrik und keine Behauptung vollständiger Communityübersicht. U1. |
| Private Wünsche | `CommunityHomeUI.lua:U.OpenHomeWishes:189`, `UXSessions.lua:U.LoadSessionEditor:68`, `U.SaveSessionPlans:92`, `FormLayoutUI.lua:U.ApplyFormLayouts:178`. Heute → Wünsche bearbeiten. Drei Prioritäten, Typ/konkretes Ziel oder Privattext, Speichern, Löschen, Schließen; dirty/revision verhindert Überschreiben offener Eingaben. | B: keine direkte Bearbeitung der Heute-Karten; Tageswünsche privat, max. drei; alte Sitzungszustände `expired/unsupported/unknown` bleiben. E: kompakte Wunschzusammenfassung mit explizitem Bearbeiten und bedarfsweise geöffnetem Editor mit Speichern/Abbrechen, keine Autospeicherung oder Veröffentlichung. Typwechsel und Prioritäten semantisch erhalten. U1, geringer bis mittlerer Aufwand. |
| Aktivitätenboard | `CommunityHomeUI.lua:U.RefreshActivityBoard:72`, `U.CreateCommunityHome:275`, `ActivityBoard.lua:B.List:67`. Hauptmenü/Heute → alle Aktivitäten. Zeit, Kategorie, Alle/Eigene/Bewerbungen, Suche; 25er-Paginierung, Listenauswahl, rechts Zusammenfassung, eigener Öffnen-Button. Fuß Folgen, Events, Archiv, Erstellen. | B: Auswahl allein zeigt keine Bewerbungs-/Verwaltungsaktionen, zusätzlicher Öffnen-Schritt nötig. Filter sind kein Typfilter: geplantes PvP und echter PvP-Hilferuf können Kategorie PvP teilen. E: Detailbereich bietet Aktionen sofort; sichtbar Typ Live/Questhilfe/PvP-Hilferuf/Termin neben Kategorie. Drei Unteransichten Entdecken/Meine/Geplant; Bewerbungen als Filter in Meine, Themenabos als Filter/Verwaltungsaktion in Entdecken. U1. |
| Gemeinsames Aktivitätsdetail | `ActivityDetailsUI.lua:U.OpenActivity:84`, `U.RefreshActivityDetails:91`, `U.CreateActivityDetails:203`. Heute ein Klick; Board auswählen + öffnen. Daten aus B.Get, bei Events Query, bei PvP RequestDetails. Zeigt Organisator, Termin/Status, aktuelle Gruppengröße, Zielgröße/Rollen, Notiz, eigene Bewerbung; Eigentümer sehen Teilnehmer und Aktionen. Fremd: Bewerbung/Zusage, zurückziehen, Whisper, Diary; eigen: bearbeiten, archivieren, Teilnehmer bestätigen/abwarten/ablehnen, Events einzeln/alle einladen. | B: derselbe Domainvorgang existiert zusätzlich auf Legacyseiten; kontextabhängige Aktionen teils nur deaktiviert ohne direkt sichtbaren Grund. Modal unterbricht Board-Navigation. E: eine wiederverwendete, typisierte Detailkomponente auf Seite oder kompakt als überlagernde Detailansicht; identischer Actions-Adapter für Deep Links. Status-/Rechtegründe beim betreffenden Button zeigen. U1. |
| Live-Gruppensuche + Bewerbungseinblendung | `UXPageGroups.lua:S.createGroupsPage:14`, `UXGroups.lua:U.SelectGroup:66`, `S.refreshGroupBrowse:84`. Interne Route groups/browse, Follow-Notifications, Legacydeep links. Online-Kontakte/Peerprofile; Kategorie/Aktivität/Notiz, eigenes Level, Rolle, Leiterverfügbarkeit; Liste/Detail, Bewerben öffnet Rollen-/Nachrichtenformular, nochmal Bewerben sendet `Z.ApplyGroup`, Zurückziehen, Whisper. Kompaktansicht blendet Liste/Filter aus (`UXViews.lua:U.OpenCompactArea:157`). | B: durch versteckte Tabs kein gewöhnlicher Einstieg mehr, Leerhinweis verweist trotzdem auf „My Group“ (:142). E: Board übernimmt Suche, spezifische Filter als erweitert; Inlinebewerbung übernimmt bestehenden Backendaufruf. Legacyroute erhält Auswahl und Anzeige, keinen zweiten Funktionsstand. U1. |
| Eigene Livegruppe, Leerzustand, Bewerberdetail | `UXPageGroups.lua:S.createGroupsPage:116`, `UXGroups.lua:S.refreshGroupMine:715`, `refreshGroupApplicants:660`, `decideGroup:768`. groups/mine u.a. Notifications (`UXNotices.lua:182`). Aktive `db.lfg[1]` bzw. leer; Bewerberliste inkl. Rolle, Ort, bisherige Kontakte, Gesamtverlauf; bearbeiten, schließen, annehmen & einladen, ablehnen, Whisper. Leerer Zustand bietet Erstellen, Vorlagen auswählen/benutzen/löschen. | B: alter Löschen-Button schließt direkt über Z.CloseGroup; gemeinsames Modal nutzt dagegen Archivbestätigung. Vorlagenverwaltung nur im Leerzustand; `groupOwnTemplate` wird explizit versteckt. E: eine eigene Aktivitätsübersicht mit anliegendem Bewerberpanel; Archivieren einheitlich bestätigen; Vorlagen erreichbar unabhängig von aktiver Gruppe. Keine zweite aktive Livegruppe ermöglichen. U1. |
| Gesendete Livebewerbungen | `UXPageGroups.lua:S.createGroupsPage:349`, `UXGroups.lua:S.refreshGroupOutgoing:197`. groups/outgoing/Notifications. Alle gespeicherten Bewerbungen, ggf. Historientitel statt aktueller Gruppe, Ort, Status, Transport und Stand; Auswahl + Zurückziehen für applied/invited. | B: Board zeigt nur aktive, zeitlich begrenzte saved applications, Legacyansicht auch übrige Status. E: Bewerbungen in Aktivitäten mit aktuelle/offline/vergangen-Filtern; vollständige Legacyinformation erhalten, Transport sekundär verständlich „Wird gesendet/Bestätigung fehlt“. U1. |
| Aktivitäten folgen | `UXPageGroups.lua:S.createGroupsPage:279`, `UXGroups.lua:U.AddGroupFollow:529`, `U.RemoveGroupFollow:537`, `S.refreshGroupFollows:544`. Board → Folgen. Kategorie PvP/Dungeon/Raid, Aktivität, Folgen, Liste, Nicht mehr folgen. `GroupFinder` Katalog. | B: Follow ist Themenabonnement für neu veröffentlichte Gruppen, weder Terminbewerbung noch einzelne Aktivität merken. E: „Suchabos für Gruppen“ als Verwaltungsdialog bei Entdecken/Benachrichtigungen; Begriff nicht mit Teilnahme verwechseln. U1. |
| Alter Heute-Matchingbereich | `UXSessions.lua:U.CreateSessionPlans:200`, `U.RefreshSessionPlans:126`. Alter groups/today-Tab versteckt, `Navigate('groups','today')` mappt Seite Heute. Matchspalte tatsächlich versteckt/reparented; verbliebene Logik Gründe, Whisper, Invite, Angebot öffnen. | B: keine zusätzliche sichtbare Heute-Unterseite inventieren. Matchingbackend weiter von Home verwendet, Editor liefert Wünsche. E: Matchingaktionen in Mitspieler-Detail bewahren; verwaiste UI kann erst im genehmigten Umbau nach Funktionsmapping entfallen. U2. |
| Aktivität erstellen Schritt 1 | `CommunityHomeUI.lua:U.OpenActivityCreator:169`, `U.ContinueActivityCreator:177`, `FormLayoutUI.lua:U.ShowActivityStep:41`. Heute/Board/Legacygruppen → Erstellen. Jetzt/Geplant, Dungeon/Raid/PvP/Quest/Andere, Ziel oder Text, Weiter, Abbrechen. | B: jetzt+PvP erstellt eine gewöhnliche Livegruppe, **keinen** PvP-Hilferuf; Quest jetzt nutzt Questhilfe, geplant nutzt Scheduled. E: klare sichtbare Typbeschreibung, Kategorie und Zeitpunkt beibehalten; kein künstlicher Menüpunkt „Erstellen“. U1. |
| Liveeditor + Vorlagenbenennung | `UXGroups.lua:U.OpenGroupEditor:443`, `U.ValidateGroupForm:362`, `U.SaveGroupTemplate:408`, `UXPageGroups.lua:groupSave:223`, `FormLayoutUI.lua:U.ApplyFormLayouts:87`, `SchedulePickersUI.lua:U.AutofillGroupNeeds:3`. Schritt 2/Detail bearbeiten/Legacyvorlage/Archiv wieder erstellen. Kategorie, Aktivitätssuche/Custom, Zielgröße, Level, benötigte Rollen, Kommentar, Laufzeit, aktuelle Gruppe; automatisch ermittelte Bedarfe, manuelle Rolleneingabe schaltet Auto aus. Zurück, erstellen/speichern, lokal Vorlage; Vorlage öffnet separaten Namensdialog (FormLayout :111). | B: eine aktive Livegruppe, Laufzeit 1..1440 Minuten, Kommentar 96 Bytes, Vorlagen max. 20 (`GroupFinder.lua:27`). Aktualisieren behält Start/Ablaufzeit. „Cancel“ und Archivieren werden später statusabhängig überschrieben. E: benötigte Rollen von belegten unterscheiden; unbekannte Rollen als Hinweis, lokale Vorlage deutlich; bisherigen Auto-/Manuellvertrag testen. U1. |
| Terminübersicht und Teilnehmer | `ScheduledGroupsUI.lua:U.RefreshScheduledGroups:64`, `U.CreateScheduledGroups:124`. Board → Events. Alle/eigene/eigene Bewerbungen, 25er-Seiten, Archivcheckbox, Liste, Details, Rollen, Teilnehmer; neu, Fremdes aus eigener Liste entfernen; fremd bewerben/zurückziehen; eigen bearbeiten, absagen, wöchentliche Vorlage, Teilnehmer bestätigen/Warteliste/ablehnen. | B: zusätzlich zum Board und Modal, mit eigenen Auswahl-/Scrollzuständen; Bearbeiten nur OPEN vor Start, Absagen OPEN; Publish-Button wird im Refresh versteckt. Terminentwurf DRAFT wird aus Liste herausgefiltert (:67). E: geplante Filteransicht im Aktivitätenraum, identische Detailaktionen plus Serie; Archivansicht nicht zweites abweichendes Archiv. U1. |
| Termineditor + Kalender-/Zeitpicker | `ScheduledGroupsUI.lua:U.OpenScheduledEditor:8`, `U.SaveScheduledEditor:27`; `FormLayoutUI.lua:U.ApplyFormLayouts:128`, `SchedulePickersUI.lua:U.CreateSchedulePickers:28`. Erstellen/Termin bearbeiten/Archiv erneut erstellen. Datum und Uhrzeit getrennt, Kalenderpopup mit Monatsnavigation/heute/Schließen, Viertelstundenpopup, Dauer, Rollenbedarf, Kommentar. | B: Datums-/Uhrzeittext und verborgene kombinierte Datumsvariable synchronisiert. Zeitzone/Organisatorrolle werden FormLayout :157 versteckt, sind im Backend aber weiterhin wirksam. `ScheduleTime.lua:T.FromLocal:36` lehnt doppelte/nicht existente Ortszeit ab und empfiehlt explizites UTC; sichtbarer UI-Schalter dazu ist verborgen. E: vorhandene Zeitkonvertierungsfehler verständlich anzeigen. Die verborgene UTC-Auswahl wird im ersten Redesign nicht ohne separate fachliche Prüfung als neuer sichtbarer Schalter angeboten; kein stiller Zeitzonenwechsel. U1. |
| Wochenserie/Vorlage | `ScheduledGroupsUI.lua:U.OpenScheduledRecurrence:43`, `U.PreviewScheduledSeries:48`, `U.CreateScheduledGroups:168`; `ScheduledGroups.lua:S.SaveTemplate:156`, `S.Preview:163`, `S.GenerateAndPublish:187`; `ScheduleTime.lua:T.Weekly:90`. Nur Terminübersicht → eigene Auswahl → Wochenvorlage. Öffnen speichert/aktualisiert bereits eine lokale Vorlage; 1..4 Termine, Vorschau, Vorlage löschen, Termine erstellen, Abbrechen. Vorschauwechsel invalidiert Freigabe. | B: gemeinsames Aktivitätsmodal bietet diese Aktion nicht; kein eigenständiger Serienmanager. Generierung veröffentlicht neue Instanzen mit leeren Teilnehmerlisten und gleicher lokaler Organisatorzeit, max. zehn öffentliche anstehende Events und 90 Tage Horizont. E: „Wiederholen …“ direkt an eigenem Termin; explizite Datumsprüfung vor Erstellung erhalten, keinen automatischen Scheduler erfinden. U1. |
| Aktivitätsarchiv + Bestätigung | `ActivityArchiveUI.lua:U.OpenActivityArchive:121`, `U.RefreshActivityArchive:90`, `U.ActivityArchiveEntries:60`, `U.RecreateActivity:70`, `U.RequestActivityArchive:12`, `U.ConfirmActivityArchive:20`. Board → Archiv; Detail/Editor → Archivieren → bestätigen. 25er-Liste, Snapshotdetails, erneut erstellen. Live/Quest aus History.Archived, Events CANCELLED/FINISHED aus Scheduled.List(true), blockierte Eventbesitzer ausgenommen. | B: erneut erstellen benötigt bei Terminen neues Datum, übernimmt keine Teilnehmer; Live/Quest erstellen neue IDs. Bestätigung prüft skalaren Snapshot gegen aktuellen Zustand, Terminrevision; Archivieren Termin bedeutet Absage samt Benachrichtigung. E: Archivfilter Typ/Eigene sauber und Rücksprung zur Ausgangsaktivität; Begriff „Absagen und archivieren“ bei Terminen. U1. |
| PvP-Gesamtseite | `UXCreate.lua:pvpHeaderButton:81`, `UXGroups.lua:U.OpenPvPHelp:592`, `PvPHelpUI.lua:U.RefreshPvPPage:36`. Kopfbutton → groups/pvp. Eigener Hilferuf/Deathcount/Voraussetzungen, Hilfe anbieten + Gebietsfilter, Hilferufe der letzten zwei Stunden, Auswahl mit Ort, Gegnerdaten wenn angefragt, Zusage/Zurückziehen, Karte, Wegpunkt, Whisper, Blockieren. Eigener Ruf: Standort aktualisieren/Erledigt/Helfer öffnen. | B: Helferbereitschaft unabhängig vom eigenen Ruf; geschlossene/offline/abgelaufene Rufhistorie bleibt auf Seite, Board zeigt engere aktive Sicht. E: als klar typisierte Aktivität in Liste und direkter Kopfzugang; kontextuelles PvP-Panel darf Voraussetzungen/Bestätigung nicht umgehen. U1. |
| PvP-Vorschau/Sendebestätigung | `UXGroups.lua:U.OpenPvpPreview:607`, `UXPageGroups.lua:pvpSend:474`, `PvPHelpUI.lua:U.CreatePvPHelpPage:104`. PvP-Seite → Hilferuf vorbereiten. Todesort/Zeit, Gegner, optional Angriffsbeschreibung, optional Gegner teilen, Pflichtcheckbox Spielerangriff, senden/abbrechen. | B: CanCall erfordert keinen aktiven Ruf, 10-Minuten-Cooldown, PvP-Flag, zwei Tode in 60 Minuten und Todesort (`PvPHelp.lua:86`), temporärer Testmodus hebt nur Zwei-Tode-Regel auf. E: Gründe sofort auf Karte und vor Vorschau zeigen; ausdrückliche Bestätigung und Freigabeoption bewahren. U1. |
| PvP-Helfermodal | `PvPHelpUI.lua:U.CreatePvPHelpPage:96`, `U.RefreshPvPPage:49`, `UXPageGroups.lua:pvpInvite:440`. Eigener aktiver Ruf → Helfer. Zusagen/Zurücknahmen, auswählen, einladen, Whisper, schließen; read/unread pro Helfer. | B: Einladung nur Zusage coming, online, Kontakt, Adapterrecht/-kapazität. Gemeinsames Aktivitätsmodal zeigt eigene PvP-Antworten ebenfalls mit Invite. E: Helfer als typisierte Teilnehmer in gemeinsamem Detail, historischer Zustand und Verfügbarkeit sichtbar; gleiche Backendfunktion. U2. |
| Handwerk Suche + Berufsdetail + Rezeptkatalog | `UXPageCraft.lua:S.createCraftPage:12`, `UXCrafting.lua:refreshProfessions:43`, `U.StartRecipeSearch:265`, `U.RecipeSearchChanged:278`. Hauptmenü Handwerk, Standard search. Suchfeld, explizit Suche/Enter, Beruf/online, Ergebnisliste gemischt Berufe und Rezepttreffer, rechts Berufs-/Trefferdetail und Katalogliste, Favorit, Whisper, Anfrage. Berufsauswahl fordert Profil/Katalog an; Rezeptauswahl setzt Rezeptkontext. | B: Textänderung filtert lokale Berufe sofort, Communityrezepte erst Suche/Enter; sichtbarer Hinweis erklärt dies. Querywechsel bricht vorige Suche ab. Katalog offline nicht ladbar, gespeicherte Rezeptdaten entsprechend markiert. Anfrage nur fremd+Rezept+online+cap30. E: eine Hauptsuche mit klaren Abschnitten Rezepte/Handwerker; Suchstatus bleibt sichtbar, Auswahl zeigt Hersteller + Materialien und Anfrage im gleichen Arbeitsraum. U1. |
| Herstellungsanfrage | `UXPageCraft.lua:craftOrderRequest:59`, `craftOrderSend:139`; `FormLayoutUI.lua:U.ApplyFormLayouts:190`. Treffer + Anfrage öffnet effektives 650×580-Modal. Gewünschte Stückzahl, Trinkgeld, Materialien gestellt, **separate Zahl Craftvorgänge**, Zutaten/Bestand/fehlend, Einkaufsliste speichern/öffnen, Nachricht, senden/abbrechen. CreateOrder, Liste speichern/Order anhängen, nach Erfolg Aufträge; Teilerfolg Order gesendet/Liste fehlgeschlagen wird angezeigt. | B: Ausbeute und Materialvollständigkeit nicht garantiert; Stückzahl und Crafts sind bewusst getrennt, kein automatisches Gleichsetzen. E: geführte Abschnitte Gegenstand → Hersteller → Materialien → Anfrage im gleichen Kontext; Details optional, zwei Mengen klar beschriften. U1. |
| Aufträge + Statusaktionen | `UXCrafting.lua:refreshCraftOrders:509`, `UXPageCraft.lua:craftOrdersFrame:229`. Handwerk → Aufträge, Ausgang/Eingang in einer Liste, abgeschlossene optional, ausgewählter Status/Übertragung/Materialien/Trinkgeld/Notiz. Handwerker REQUESTED annehmen/ablehnen; ACCEPTED bereit/abbrechen; READY abbrechen. Besteller READY Übergabe bestätigen/abbrechen, REQUESTED/ACCEPTED abbrechen. Materialplanung für gewählten Auftrag; alle Einkaufslisten auch ohne Auswahl. | B: dynamisch überschriebene Buttonhandler, terminale standardmäßig verborgen. E: verständliche Eingangs-/Ausgangsfilter, Statusschritt plus Übertragung getrennt; nur gültige Aktionen. U1. |
| Einkaufslisten/Materialplanung + Auftragslistenanlage | `UXCrafting.lua:U.OpenOrderMaterials:359`, `U.RefreshMaterialPlans:376`, `UXPageCraft.lua:materialOrderForm:252`, `materialPlanFrame:290`. Alle Listen oder kontextuell aus Anfrage/Auftrag; wenn noch keine Liste, Dialog mit expliziter Craftzahl. Links private Listen, rechts Auftrags-/Privatstatus, Zutaten, Recheck, löschen, manuell erworben/reset, Angebote suchen, gefundenes Angebot öffnen, Anfrage fortsetzen. | B: max. 100 private Listen, nur Taschen; älteste aktive Liste reserviert zuerst, Handmarkierung bestätigt keinen Bestand/Übergabe; fehlender/terminaler Auftrag macht Liste inaktiv; max. 20 Communityangebote, kein AH-Scan (`MaterialPlanner.lua:4,81,99,131,159`). E: Materialien im Rezept-/Auftragsdetail als eigener Bereich, zentrale Listenverwaltung zusätzlich direkt auffindbar, Fortschritt erklärbar. U1. |
| Meine Berufe + Scanstatus + Berufshistorie | `UXPageCraft.lua:craftMineFrame:183`, `UXCrafting.lua:craftStatusText:21`; `ProfessionHistoryUI.lua:U.CreateProfessionHistory:13`, `U.RefreshProfessionHistory:3`. Handwerk → Meine Berufe. Berufszahl, Katalogabdeckung, Scanzeit, eigenes offenes Berufsfenster nötig, Berufe scannen/erneut prüfen, Rückmeldung, Historienzeilen pro Beruf; Klick öffnet Verlauf mit CRAFT + Berufsname. | B: eigentliche eigene Rezepte sind in Suche beim eigenen Beruf, nicht als Liste auf Meine Berufe. Teilscans ergänzen, vollständige Scans dürfen ersetzen (`ProfessionScan.lua:S.Commit:62`). E: Berufe als kompakte Karten mit Skill, Vollständig/Teilweise, Scanzeit, „Rezepte ansehen“, kontextuellem Scanhinweis; Historie optional. U1. |
| Handel suchen + Angebotsdetail | `UXPageTrade.lua:S.createTradePage:12`, `UXTrade.lua:offers:11`, `refreshOffers:227`, `showOffer:200`. Hauptmenü Handel → finden. Suchtext/Itemvorschlag, Art, Kategorie, Reset, speichern, Stückpreis min/max, Sortierung, Liste, Detail, Whisper; kompakt Auswahlblendung. Nur eigene gültige und online empfangene nicht abgelaufene Angebote. | B: Filter reagieren sofort; Preisfilter in Gold und auf Stückpreis, Vorschau zeigt Stück/Gesamtpreis; Itemvorschlag setzt exakte itemID. E: Suchfeld + Art sofort; Kategorie/Preis/Sortierung gebündelt optional, aktive Filter sichtbar. Detailaktionen Inline, keine Kaufabwicklung behaupten. U1. |
| Angebot erstellen/bearbeiten, lokaler Entwurf | `UXPageTrade.lua:tradeMineTab:17`, `offerSave:104`, `offerSaveDraft:168`, `UXTrade.lua:U.EditOffer:135`, `U.ValidateOfferForm:100`. Permanenter Untertab Erstellen; Verwaltung → Öffnen. Art SELL/BUY/SERVICE, Gegenstand/Dienstleistung, Menge, Gesamtpreis G/S/K, Laufzeit 1..1440, Notiz, Vorschau, veröffentlichen/Änderungen speichern, verwerfen, lokal speichern. | B: active editID darf nicht verschwunden sein; Publish konsumiert passende gespeicherte Quelle, Vorlagen bleiben laut TradeManager. UI-Draft und gespeicherter lokaler Entwurf sind verschiedene Zustände. E: globale Aktion „Angebot erstellen“ öffnet Editor, drei Tabs Finden/Meine Angebote/Suchalarme. Kein stiller Publish bei Speichern des privaten Entwurfs. U1. |
| Handelsverwaltung | `UXPageTrade.lua:tradeManageFrame:209`, `UXTrade.lua:refreshTradeManage:458`. Handel → Verwaltung. Aktive/pausierte/Entwürfe/abgeschlossene/abgelaufene/Vorlagen gemeinsam sortiert; Auswahldetail. Aktiv bearbeiten, pausieren, erledigt, duplizieren, Vorlage speichern; gespeichert öffnen/erneut anbieten/Vorlage benutzen/löschen. | B: Zustand steuert Buttontext und Sichtbarkeit; aktiv nicht über gespeicherte Delete-Löschung, sondern Complete/Pause mit Retract. Pausierte/Entwürfe zusammen max. 100, Vorlagen max. 20 (`TradeManager.lua:105,116,129`). E: „Meine Angebote“ mit Statusfilter und kleinen Mengen statt technischem Verwaltungstitel; Vorlagen als Editoraktion/Filter, keine zusätzliche Hauptseite. U1. |
| Suchalarme/gespeicherte Suchen + Updates | `UXPageTrade.lua:tradeSaveSearch:41`, `tradeRulesFrame:283`, `UXTrade.lua:refreshTradeRules:361`, `TradeManager.lua:M.SaveRule:37`, `M.OnBundle:71`. Suchfilter speichern erzeugt lokalen Alarm; Tab Suchalarme zeigt Regeln, Auswahl, Filter anwenden, löschen und max. 30 letzte Updates. Updateklick markiert gelesen, öffnet kein Angebot. | B: bestehende Treffer nach Login bleiben still; neue/änderte/geschlossene Angebote erzeugen Hinweise. E: „Suche speichern“ konsistent „Suchalarm speichern“, Alertzeile führt zum bestehenden Angebotsdetail wenn noch verfügbar; geschlossene Treffer als Snapshot/Status. Letzteres ist UI-Routingvorschlag, keine Erweiterung des Netzwerks. U1. |

#### A.6.1 Fach- und Berechtigungsverträge

| Typ | B: Autorität / erlaubte UI-Aktionen | E: Konsequenz |
|---|---|---|
| Livegruppe | `ActivityDetailsUI.lua:U.JoinActivity:179` → Z.ApplyGroup(role,note), zurückziehen → Z.WithdrawGroup; Eigentümerentscheidung → `UXGroups.lua:decideGroup:768`, prüft applied, Kontakt, online bei Invite, Zielkapazität und A.Invite-Recht. Erst erfolgreicher nativer Invite setzt invited und sendet Status. `Adapter.lua:A.Invite:334` validiert Identität, Online und Gruppenrecht, natives API via pcall. | „Annehmen & einladen“ nicht als bloßes Statusschreiben vereinheitlichen; gesendet/eingeladen/beigetreten unterscheiden. Berechtigungsgrund statt toter Schaltfläche. |
| Questhilfe | `ActivityDetailsUI.lua:179,193` → ApplyQuest/WithdrawQuest/DecideQuestApplicant. Keine Rollenwahl, optional Nachricht, eigene Logik. | Gemeinsamer Renderer, separater Questadapter; gemeinsame Quests und Questhilfe nicht semantisch verschmelzen. |
| Geplantes Event | `ScheduledGroups.lua:S.Enabled:99` verlangt store, consent, autoDiscovery, visible, identityReady, nicht offlineOnly. CanApply :309 verlangt aktuelle autorisierte Route mit scheduledGroups, verifizierte Session, <300s Verifikation, OPEN vor Start, keine pending Operation; Apply prüft Rolle hat Slot. CanDecide :333 prüft Teilnehmerrevision, Status, Zeit, Kapazität je Rolle, blockiert und enabled. CanWithdraw :325 nutzt eigenes pending-/Ende-/Editierbarkeitsmodell. | Bestätigen ist **keine Einladung**. `ActivityDetailsUI.lua:canInviteParticipant:34` verlangt CONFIRMED, gleiche Teilnehmerrevision, OPEN vor Ende, online/Kontakt/nicht blockiert/Einladerecht/nicht schon Mitglied/kein 30s-Pending; alle einladen ist bewusst Nutzeraktion. Revision bei Auswahl halten und vor Aktion revalidieren. |
| PvP-Hilferuf | `PvPHelp.lua:P.Respond:188` nur aktiver fremder Ruf, coming/withdrawn; P.InviteHelper :192 nur eigener Ruf+coming+Kontakt, A.InvitePvp :348 prüft Rolle und 5/40-Kapazität. Kein Event-Wartelisten-/Bewerbungsstatus. | Aktionen „Ich komme/Zusage zurückziehen/Helfer einladen“, kein künstliches Event-Statusmapping; Erstellen unterliegt CanCall und Angriffbestätigung. |
| Herstellung | `CraftOrders.lua:O.Create:81`: online, cap30, gültiges Rezept/Mengen/Trinkgeld/Notiz, max.100 laufend und max.5 pro Handwerker, 24h REQUESTED. `validTransition:90`, `O.Transition:102`: Handwerker besitzt Revision, Besteller sendet Operation mit erwarteter Revision; Annahme prüft Rezept weiterhin im eigenen Katalog. | UI-State und delivery getrennt. Kein „Erledigt“ allein durch Materialmarkierung; Übergabe bestätigt Besteller. Keine automatische Produktion, Inventarverschiebung oder Zahlung. |
| Materialsuche | `MaterialPlanner.lua:seller:159` verlangt consent/identityReady/nicht offlineOnly, Kontakt/Peer, unblocked, fremd, online; GetOffer :170 gültiges SELL-Angebot mit exakt itemID, gültige Preis/Menge. `UXTrade.lua:U.OpenMaterialOffer:340` revalidiert Liste aktiv + ausgewählte Zutat + Angebot vor Navigation. | Herkunft/Frische nennen; fremder Bestand/Verfügbarkeit nicht garantieren; Handelsdetail und Whisper nur explizit öffnen. |
| Matching | `SessionPlans.lua:enabled:114`, `P.CanInvite:234`: Wünsche aktiv, Austausch/Identität; Match aktuell, keine unknown-Verfügbarkeit, frei/nicht in Gruppe, Einladungspending, Gruppenrecht/Limit, Questmatch delegiert Questhelper. B.Home benötigt aktive private Wünsche und verifizierte Daten für „passend“. | Nicht passende Daten als persönliche Empfehlung ausgeben; leerer Zustand unterscheidet keine Wünsche, Austausch aus, noch ungeprüft, keine Treffer. |

**B:** `ActivityBoard.lua:B.List:67` hat Cache über viewRevision und maximal 5 Sekunden; `ActivityParty.lua:P.Info:37`/`:P.Query:44` liefert Fremdgruppe nur bei autorisierter Session und <120s frischen Daten, Querydrossel 30s. Fehlende aggregierte Gruppengröße ist „Unbekannt“, keine Null. Party.Tick kann zusätzlich Livebedarf an native Rollenänderungen anpassen. **E:** sichtbare Teilansicht inkrementell aktualisieren, bestehende Dirty-/Throttle-/Cacheverträge respektieren, keine Netzwerkrequests pro Tabellenzeile pro Render hinzufügen.

#### A.6.2 Weitere belegte Workflowbrüche

1. **B/U0-Kandidat:** Herstellungskontext geht beim Materialeinkauf verloren: Anfrage → Einkaufslisten nutzt SetCraftView und bewahrt Kontext; Materialangebot → `UXTrade.lua:U.OpenMaterialOffer:350` → Navigate → `UXLayout.lua:U.Page:218` → CloseDialogs → :561 setzt `craftOrderContext=nil`. `UXCrafting.lua:U.RefreshMaterialPlans:417` aktiviert Fortsetzen nur mit passendem Kontext. Gespeicherte private Liste bleibt, aber Anfrage kann nach dem Seitenwechsel nicht darüber fortgesetzt werden. **E:** expliziten UI-Rücksprungkontext mit peer+recipe+planID und ungesendeten Formwerten bewahren, bei Rückkehr Backendberechtigung neu prüfen. Keine neue öffentliche Datenhaltung. **V:** End-to-End mit aktuellem Suchtreffer, Materialangebot und Rückkehr bestätigen.
2. **B/P1:** Wochenserienaktion nur in Events-Legacyansicht, nicht im sonst einheitlichen Modal. Gleiche Aktivität hat unterschiedliche erreichbare Fähigkeiten. **E:** Wiederholen direkt im Eigentümerdetail, bestehendes Vorschauformular wiederverwenden.
3. **B/P1:** Gruppen-Vorlagenbenutzung/-löschung liegt in groups/mine im Leerzustand; Hauptpfad versteckt diesen Tab und zeigt eigene Aktivitäten primär als Modal. Kein offensichtlicher Weg von normalem Board zu dieser Verwaltung. **E:** Erstellen → Vorlage verwenden, plus zugängliche lokale Vorlagenverwaltung; nie auf Abwesenheit einer aktiven Gruppe beschränken. **V:** alle vorhandenen Slash-/Notiz-/Benachrichtigungslinks im Gesamtaudit prüfen, bevor „unerreichbar“ behauptet wird.
4. **B/P1:** expliziter UTC-Fallback bei Zeitkonvertierungsfehlern wird vom Backend verlangt, UI blendet Zeitzonenauswahl aus (`FormLayoutUI.lua:157`). **E:** vorhandene Konvertierungsfehler verständlich erklären und Zeitlogik erhalten; Sommerzeitlücken/-doppelstunden nicht still korrigieren. Die sichtbare UTC-Auswahl ist außerhalb dieses Plans separat fachlich zu prüfen.
5. **B/P1:** eigener/gespeicherter Beteiligungsstatus ist über Board, Modal, Legacybewerbung, Events und Inbox verteilt; Heute zeigt gespeicherte Offline-Live/Questbewerbungen nicht. **E:** „Meine Bewerbungen“ als primär sichtbarer Filter, Teilnahmestatus von Zustellstatus trennen.
6. **B/P1:** sichtbare Handwerk-Tabs suggerieren drei Bereiche, privates Listenwerkzeug versteckt sich im Auftragsbereich. **E:** Aufträge mit Einkaufslisten als zusammengehörige Arbeitsansicht, direkter sekundärer Listenzugang und kontextuelle Materialien; kein zusätzlicher Hauptmenüpunkt.
7. **B/P2:** Berufshistorie ist eine nachträglich angehängte 64px-Liste mit 42px-Zeilen (`ProfessionHistoryUI.lua:15`), bei mehreren Berufen zusätzlicher Scrollbereich. **E:** Scanfrische/Teilstatus direkt an Beruf, Verlauf auf Wunsch.
8. **B/P1:** Alertklick liest nur, öffnet nicht Treffer; Gruppenfolgen und Suchalarme verwenden uneinheitliche Benennung. **E:** „Suchabos“ als verständlicher Oberbegriff, Gruppenthemen und Handelsfilter funktional getrennt; markiert-gelesen separat von öffnen modellieren.

### A.7 Detailinventar: Charaktere, Profile, Quests, Mitspieler und private Kontakte

| Ansicht / Zustand | Codeanker (Funktion:Zeile) | Tatsächlicher Einstieg und Navigation | Daten / Aktionen / Einschränkungen | UX- und Layoutbefund |
|---|---|---|---|---|
| Meine Charaktere: Liste/Filter/Summen | `AccountOverviewUI.lua:U.CreateMyCharacters:263`, `U.MyCharactersRows:69`, `U.RefreshMyCharacters:216`, `U.OpenMyCharacters:375` | Einstellungen → Meine Charaktere; Profil-Tab; Slash-Aliase; `OpenAccountOverview` ist Alias | Lokale Accountliste + Overview-Snapshot + Berufe aus lokalen Charakterprofilen + optionale Utility-Kopie. Realm/Fraktion aus tatsächlich vorhandenen Charakteren, Show hidden, kombinierte Namen-/Itemsuche, Goldsumme als letzter gespeicherter Wert, fehlende/älteste Werte | Viele Verwaltungs- und Aufnahmeoptionen über der eigentlichen Auswahl. Summen beziehen sich auf realm/faction/hidden-gefilterte `scoped`, nicht auf nur namensgefundene Zeilen; E: Suchscope sichtbar benennen |
| Ausgewählter Charakter: Kopf/Daten | `AccountOverviewUI.lua:header:141`, `details:158`, `selectedRow:211` | Klick links; ohne vorhandene Auswahl bevorzugt aktueller Charakter, sonst erste Zeile | Name/Klasse/Level/Realm/Fraktion, Main/Twink, Gold, Login/Update, Utility-Herkunft, Erholungs-EP, Spielzeit, Berufe, Taschen-/Bankanzahl und Zeitstempel | Getrennte Datenfelder sind semantisch wichtig, im Ist jedoch nur generische Scrollrows. Utility-only bricht nach Herkunft/Grunddaten ab (:173) |
| Aufzeichnungsschalter | `AccountOverviewUI.lua:271`, `AccountOverview.lua:O.SetEnabled:103`, `O.SetInventory:114` | Direkt über Liste | Login-Grunddaten separat von Taschen/Bank opt-in; disabled inventory control bei ausgeschalteter Basisaufnahme; Unknown bleibt Unknown | E: als ruhige Aufnahme-Zeile/Popover bei Datenstatus; bestehende Defaults und explizite Altentscheidung unverändert |
| Weitere Aktionen / Ausblenden | `AccountOverviewUI.lua:toggleMenu:256`, `:297`, `AccountOverview.lua:O.SetHidden:108` | Auswahl → More actions → Hide/show | Aktueller Charakter nicht ausblendbar. Daten/Links bleiben; reversible lokale Sichtbarkeit. Show hidden holt ihn zurück | Kein öffentliches Verstecken; E: Label „In dieser Übersicht ausblenden“ beibehalten. Achtung: `UXMemberGroups.lua:228` nutzt Hidden auch beim Ergänzen eigener bekannter Charaktere im Gruppenmodell; Aussage „nur diese Ansicht“ UI vs tatsächliche Modellwirkung testen |
| Charakter löschen: Bestätigung | `AccountOverviewUI.lua:confirmDelete:249`; `UXCreate.lua:265`; `Main.lua:Z.RemoveCharacter:110` | Auswahl → More → Delete → Bestätigung | Nur bestehender Community-Char im eingeloggten Realm/Fraktion und nie aktueller. Entfernt lokalen Profil-/Berufs-/Rezept-/Draft-/UI-/PvP-/Overview-Bestand sowie Aliasreferenzen/Kontakte/Peers/Kataloge und private Markierungen; historische Einträge bleiben. Main fällt auf eingeloggten Char zurück. Utility-Zuordnung wird entfernt | Konkreter Konsequenztext vorhanden, 460×255 Bestätigung mit 160px Text. **V:** deutscher langer Text bei Skalierung nicht abgeschnitten. Kein generisches „Entfernen“ verwenden |
| Utility-Übernahme | `AccountOverviewUI.lua:308`; `AccountOverview.lua:O.UtilityLoaded:273`, `O.UtilityRows:279`, `O.ImportUtility:294`, `O.List:358` | More → Take over … nur bei geladenem Utility und nicht neuerem/read-only Overviewformat | Liest Utility, schreibt es nicht; ausdrückliche Snapshot-Kopie ersetzt frühere Kopie. Identität Name+Realm+Fraktion; doppelte/mehrdeutige Zuordnungen ausgeschlossen, Anzahl gemeldet; Utility-only Charaktere nicht Main-setzbar/löschbar; neuere Daten feldweise mit Herkunft | E: Importstatus und Aktion an Seitenkopf/Datenquellen; keine automatische Übernahme/Migration hinzufügen |
| Globale Gegenstandssuche | `AccountOverviewUI.lua:searchResults:188`, `AccountOverview.lua:O.Search:434` | Gemeinsames Suchfeld | Name ab 2 Zeichen oder numerische Item-ID; nur gespeicherte Bags/Bank der gefilterten sichtbaren Charaktere; insgesamt höchstens 50 Treffer, bis 50 Itemnamen-Anfragen; Holder mit Taschen-/Bankanzahl; unbekannte Namen werden angefragt, Hinweis auf erneut suchen | Noch kein vollständiger Inventar-/Bankbrowser. E: eigener Modus „Gegenstände“ mit unverändertem Backend; keine falsche Live-Bank suggerieren |
| Öffentliches Charakterprofil bearbeiten + Vorschau | `UXPageProfile.lua:S.createProfilePage:10`, Save `:52`; `UXViews.lua:U.SetProfileView:83` | Einstellungen → Character profile; Profil-Untertab | Aktueller Char, Anzeigename max32, bevorzugte Rolle/NONE, Notiz max64, Vorschau; Save validiert, schreibt Z.db und `U.Publish`; Show profile in Members setzt eigenen exakten key + follow=false und navigiert Mitspieler | Öffentliches Profil ist **nicht** Accountdaten. Eingaben charakterbezogen, Sichtbarkeitsfreigaben mittlerweile accountweit (siehe Abschnitt 3). FormLayoutUI:219–221 überschreibt Eingabe-/Buttonpositionen |
| Profil-Unteransicht Darstellung | `UXPageProfile.lua:81` | Einstellungen → Display settings; Profil-Tab | Standardgröße 1060×690, Position+Scale reset; weitere globale Layoutfunktion außerhalb dieses Teilbereichs | Erfordert für Settings-Konzept Auflösung des Profil-Tabs; E: echte Kategorie Darstellung |
| Profil-Unteransicht Verbindung/Freigaben | `UXPageProfile.lua:97` | Einstellungen → Connection and privacy; Profil-Tab | Network UserSummary, visible, shareProfessions, Aktualisieren, technische Diagnose, NetworkSetup.Show; `Z.SetPreference` statt direktem UI-only Schalter | Profilnotiz und Freigaben räumlich getrennt. E: kleine Statuszeile im Profil und genau eine kanonische Freigabefläche unter Einstellungen |
| Mitspieler Liste: flach / nach Main gruppiert | `UXPageMembers.lua:S.createMembersPage:68`; `UXMembers.lua:refreshMembers:923`, `characterItem:635`, `groupedItems:851`; `UXMemberGroups.lua:build:82` | Hauptmenü Mitspieler; Deep Links aus Profil/anderen Bereichen | Suche, ONLINE/ALL, Klasse, Beruf, kombinierter Filter All/Favorites/My guild/private Kategorien, Sort online-first/last seen/name/level, Group by main; Refresh → DiscoveryTick(true). Gruppen lassen sich auf-/zuklappen; Main als Kopf, aktiver Twink in Subtitle; Matches auf Twinks ausgewiesen | Sechs Filter+Grouping vor Liste wirken administrativ. Sort/klasse/beruf sollten in erweiterte Filter; Such-/Online/Favorit/Gilde sofort sichtbar. Keine Rollen-/Identitätsdaten eines virtuellen Main erfinden |
| Mitspieler Detail und kompakte Detailansicht | `UXMembers.lua:refreshMemberDetail:468`, `contactTarget:399`, `updateContactActions:460`; `UXViews.lua:U.OpenCompactArea:135`; `CommunityHomeUI.lua:U.RefreshMemberCategories:194` | Zeilenklick; kompakt öffnet Vollbreite und Back to list | Profilname/Klasse/Level/Status/Layer, aktueller oder letzter Ort, öffentliche Rolle/Gilde/Berufe/Notiz, Main, bekannte Charaktere; Whisper/Invite auf echtes Kontaktziel; eigene/blocked nicht kontaktierbar; Invite nur online, Adapter prüft weiter | Späteres HomeUI baut Kopf+scrollbare Facts+wrap-category-chips+Notiz+Aktionen unten; nicht die alten Koordinaten als Ist-Bild verwenden. Details zeigen „Acts on“ und Kontaktziel; E: klar „Notiz für X“ vs „Einladen: aktiver Y“ |
| Favorit / private Notiz | `UXPageMembers.lua:94,104,147`; `UXMembers.lua:bindPrivateNote:247`, `U.SavePrivateNote:265`; `Social.lua:S.ToggleFavorite:168`, `S.Note:174` | Auswahl → Favorit oder edit+Save; auch Tagebuch | Lokal realm/faction-geteilte Social-Daten; 500 Zeichen Notiz, Drafts pro echtes Kontaktkey, kein Kopieren auf Main/Alt. Favorit nicht für eigene Chars | E: Bearbeitung bleibt im Kontaktpane; expliziter Empfänger neben Notiz bei Gruppenansicht |
| Kontakt-Kategorien inline | `CommunityHomeUI.lua:306,313`; `CategorySettingsUI.lua:U.NewCategoryChip:6`, `U.SyncCategoryControls:20`; `SocialCategories.lua:C.Set:71` | Kontakt auswählen → Chip; früherer Private categories-Button versteckt | Mehrfachtags, max20 Definitionen, max1000 Kontakte; keine self/blocked; Validation keyed identity; Entfernen letzter Kategorie bewahrt lokal erreichbaren Kontakt/Notizen/Favoriten | Chips max3 Zeilen dann eigener Scrollbereich. E: wichtigste Tags + „Weitere“ nur bei tatsächlicher Enge, alle weiterhin erreichbar |
| Alter Kategorie-Kontaktpopup (Legacy, kein normaler Pfad) | `UXPageMembers.lua:163`, `UXMembers.lua:U.OpenPrivateCategories:297` | Konstruktion vorhanden, Öffnungsfunktion später durch HomeUI:313 ersetzt | Kontaktselector, Summary, Checkboxen. Handler verwenden categoryKey, neuere Chiphandler memberKey | Nicht als aktive zusätzliche Navigationsstufe zählen. Bei Umbau erst Referenzen/externen Aufruf prüfen, Legacy-Entry auf neue Kontaktansicht aliasen |
| Kategorie-Definitionen bearbeiten | `CategorySettingsUI.lua:U.CreateCategorySettings:50`, `U.RefreshCategorySettings:36`, `SocialCategories.lua:C.Add:99`, `C.Rename:111`, `C.Remove:117` | Einstellungen → Private contact categories | Liste → Name → Rename/Add; Delete zeigt zweite konkrete Aktion „Remove category and its marks“, entfernt Definition+alle Zuordnungen; newer format read-only | 650×450 modal, fixe 196px Buttons; keine Kontextverknüpfung aus Kontaktpane zur Verwaltung. E: „Kategorien verwalten“ im Filter/Pane und kanonische Verwaltung unter Mitspieler/Kontakte; Einstellungen nur Alias falls nötig |
| Social Diary: Übersicht, Filter, Detailtimeline | `SocialDiaryUI.lua:U.CreateSocialDiary:84`, `U.RefreshSocialDiary:25`, `U.OpenSocialDiary:65`; `SocialDiary.lua:D.List:235`, `D.Timeline:265` | Mitspieler → Social diary; Aktivitätsdetails → Social diary für Owner oder ausgewählten Teilnehmer; Slash diary/tagebuch für Target | 25 Einträge/Seite, Search (Name/Notiz/letzte Zone), ALL/KNOWN/FAVORITES/NOTES/GROUPED, LAST/COUNT/NAME; First/Last/count/level/class/timeline; Favorit/Known/500-Zeichen-Notiz; manuell gespeicherte Kontakte ohne Begegnung weiter sichtbar | 650×550 Dialog, eigene Pagination und zwei Scroller + Note. E: Kontextaktion „Meine Kontakte / Social Diary“ und Timeline im rechten Kontaktpane; kein zusätzlicher verpflichtender Haupt- oder Untermenüpunkt; Board-Link öffnet denselben Kontaktkontext |
| Social Diary Aufnahmeoptionen und Entfernen | `SocialDiaryUI.lua:89,93,105,121`; `SocialDiary.lua:D.SetEnabled:68`, `D.SetSource:73`, `D.Forget:218` | Direkt im Diarydialog | Aufnahme standardmäßig aus, Quellen target/mouseover/nameplates/group einzeln; keine Chats; `Forget` entfernt nur Diary-row, nicht Favorit/Notiz (kann deshalb in Liste bleiben). Newer format read-only | **B:** Remove ist direkte Aktion ohne Bestätigung. E: „Begegnungsverlauf löschen“ und Konsequenz erklären; Favorit/Notiz bleiben absichtlich. Bestätigung nur wenn Verlustumfang das rechtfertigt |
| Kontakthistorie / Quest-Helfer-Verlauf | `CommunityHomeUI.lua:311`; `UXPageQuests.lua:226`; `UXPageProfile.lua:S.createHistoryPage:127`; `UXViews.lua:U.RefreshHistory:332` | Mitspieler → Contact history für memberKey; eigene Questanfrage → Gesamten Verlauf; Einstellungen → History | Transaktions-/Aktivitätshistorie, nicht identisch mit Diary-Encountertimeline. Spielerhistorie und vollständige Historie haben eigene Löschbestätigungen | E: im Kontaktpane zwei klar benannte Abschnitte „Gemeinsame Aktivitäten“ und „Begegnungen“ mit unveränderten Stores/Löschgrenzen; globaler Verlauf unter Aktivitäten → Verlauf; bestehender Settings-Einstieg bleibt ein kompatibler Alias |
| Gemeinsame / meine Quests | `UXPageQuests.lua:133`; `UXQuests.lua:U.RefreshSharedQuests:41`; `QuestHelper.lua:Q.AllMatches:169` | Hauptmenü Quests default shared; sichtbarer Shared-tab | Eigener gescannter Questlog, gruppiert nach Questkategorie, einklappbar, Titel-Suche; Trefferanzahl/Status pro Quest; rechts reale Mitspieler mit Status/Ort/Anzahl weiterer gemeinsamer Quests | Bereits produktiver Standard. Ein Questklick zeigt Mitspieler unmittelbar; nicht erst Hilfeanfrage nötig. Copy muss „Gleiche Quest“ vs „Sucht ausdrücklich Hilfe“ erklären |
| Gemeinsame Quest: Spieler auswählen / Invite / Whisper | `UXQuests.lua:151,174,186`; `UXPageQuests.lua:152`; `QuestHelper.lua:Q.CanInvite:176`, `Q.Invite:186` | Quests → Quest → Spieler → Aktion | Einladung revalidiert gültigen eigenen Scan, frischen geteilten Meshrecord, AVAILABLE, nicht schon Gruppe/pending, eigenes Invite-Recht, Gruppenkapazität und C_QuestLog.IsOnQuest; 60s pending | Einladung ist keine Quest-Hilfebewerbung und kein Nachweis gemeinsamer Erfüllbarkeit. E: Inlineaktion pro Mitspieler spart Auswahl, muss dieselbe Revalidierung behalten |
| Gemeinsame Quest → explizite Hilfeanfrage | `UXQuests.lua:U.OpenSharedQuestRequest:14`; `UXPageQuests.lua:163`; `FormLayoutUI.lua:230` | Quest auswählen → Find help → Editor als Dialogschritt | Bei bestehender Anfrage öffnet deren Editor statt zweiter Anfrage; sonst Titel/ID/Level vorbefüllt. Ein aktiver Request pro Charakter | **E:** Button „Hilfe für diese Quest suchen“, klare Meldung „Du bearbeitest deine bestehende Anfrage“, nicht vermeintlich neue Anfrage suggerieren |
| Questgruppen: Vorschläge / Mitglieder / Abdeckung | `UXPageQuests.lua:99`; `UXQuests.lua:U.RefreshQuestGroups:193`; `QuestGroups.lua:G.BuildSuggestions:77`, `G.GetCoverage:45` | Sichtbarer zweiter Quest-tab; Heute-Schnellaktion `CommunityHomeUI.lua:262` | Lokale begrenzte Vorschläge aus frischen Overlaps; max40 Kandidaten, max4 vorgeschlagene Mitspieler, max10 Vorschläge; coverage = mindestens ein Mitspieler, intersection = alle inkl. selbst; Members/Quests separat | Fehlende Daten bleiben unbekannt; keine Completion-/Erreichbarkeitsgarantie. E: hilfreiche Erklärung direkt neben Zahlen, „Vorschlag“ nicht bereits „Gruppe“ |
| Questgruppe: Einzelinvite / Whisper | `UXQuests.lua:U.InviteQuestGroupMember:293`; `UXPageQuests.lua:119` | Vorschlag → Mitglied → Aktion | Revalidiert GetCoverage, Invite wiederum QuestHelper.Invite am ersten gültigen gemeinsamen Quest; kein automatisches Sammelinvite | E: Aktionen je Mitglied; keine neue automatische Gruppenbildung ohne separate Freigabe |
| Fremde explizite Questhilfe: Legacy-Liste/Detail + Bewerbungsformular | `UXQuests.lua:foreignQuests:309`, `U.SelectQuest:325`, `S.refreshQuestBrowse:332`; `UXPageQuests.lua:17,40` | Tabs versteckt; SetQuestView(browse)/alte Deep Links; regulär Aktivitätsboard-Detail ersetzt dies | Suche Spieler/Titel/Notiz/Ort, Zone, Level; nur online contacts mit gültiger Anfrage; Hilfe anbieten öffnet optional64 Zeichen Note dann Z.ApplyQuest; zurückziehen via Z.WithdrawQuest; whisper | Nicht als normal sichtbaren Quest-tab behaupten. Empty state verweist auf verstecktes „My Quest Request“ (:366), daher nachweislich veraltete Orientierung |
| Eigene Questanfrage: Legacy-Summary/Helfer | `UXQuests.lua:S.refreshQuestMine:680`, `refreshQuestApplicants:623`, `decideQuest:720`; `UXPageQuests.lua:184` | mine-Tab versteckt; Anfrageerstellung/legacy Route; regulär eigenes Activitydetail | Edit/CloseQuest, Helferstatus, unread, Ort, frühere Kontakte, Annehmen & einladen oder ablehnen; accept nur applied+online und ruft erst Adapter.Invite, dann Decision+QS-Queue | Geschäftslogik wird vom gemeinsamen Detail via U.DecideQuestApplicant wiederverwendet (`ActivityDetailsUI.lua:200`); Daten und Status dürfen nicht beim UI-Umbau neu modelliert werden |
| Questanfrage-Editor | `UXQuests.lua:U.OpenQuestEditor:601`, `CaptureQuestDraft:540`, `ValidateQuestForm:567`; `UXPageQuests.lua:229`; `FormLayoutUI.lua:230` | Globale Aktivität erstellen → Quest; gemeinsame Quest → Hilfe; eigene Activity → Edit | Questlogpicker+Suche oder manuell/Levelgruppe, Titel/Zone/min/max/Dauer/Notiz/Vorschau, SaveQuest, BackActivityStep, Draft verwerfen; Save verhindert zweite aktive und stale edited request | Pickeroption nicht zwingend echte Quest, Quest-ID 0 für manuell. E: „Quest aus Log“ vs „Eigene Beschreibung“; vorhandenen Draft-/Ablaufzustand erhalten |
| Eigene Hilfsangebote: Legacy-Liste/Detail | `UXQuests.lua:S.refreshQuestOutgoing:405`; `UXPageQuests.lua:167` | outgoing-Tab versteckt; alte Route/Notification, regulär Board mit gespeichertem Bewerbungsstatus | Sent applications, alte Titel aus History-Fallback, state/time/transport/Ort, Withdrawal nur applied/invited | E: unter Quests → Questhilfe mit Filter „Meine Hilfsangebote“ und under Activities „Meine Bewerbungen“ dieselben Datensätze, kein duplizierter State |
| Gemeinsames Activitydetail für QUEST | `ActivityDetailsUI.lua:U.OpenActivity:84`, `U.JoinActivity:179`, `U.WithdrawActivity:188`, `U.DecideActivity:193`, `CreateActivityDetails:203` | Aktiver Board-Eintrag in Heute/Aktivitäten → Modal | Fremd ApplyQuest/WithdrawQuest+Notiz; eigener Request Teilnehmerwahl/decideQuest, Edit, Archive-Workflow, Whisper und Diary; button gating refreshed aus aktuellem Boardrecord | Verbindlicher regulärer Pfad; Legacyrequest-Seiten als Kompatibilitätsroute betrachten, nicht als parallel neues Produktmenü |

#### A.7.1 Datenschutz, Datenbesitz und Identität

| Daten/Regel | Nachweis | Konsequenz für Redesign |
|---|---|---|
| Gold, RestXP, Spielzeit, Bags/Bank bleiben lokal; jedes Feld eigene Zeit | `AccountOverview.lua:1–19`, `O.List:358`, `AccountOverviewUI.lua:158` | Keine gemeinsame Datenstruktur mit öffentlichen Profilformularen; „Privat, auf diesem Rechner gespeichert“ oberhalb Übersicht; globales „aktualisiert“ ersetzt keine Bankzeit |
| Lokales Accountprofil vs öffentliches Profil | `AccountOverview.lua:330` liest professions aus lokalem character profile; `UXPageProfile.lua:52` speichert öffentlich publizierbare Z.db Felder | Kartendaten nicht aus Preview/Publish ableiten. Öffentliche Bearbeitung nur eingeloggter Char; andere gespeicherte Chars nicht scheinbar remote editierbar machen |
| Sichtbarkeit/Berufsfreigabe accountweit, Profildaten bleiben pro Char | `AccountPreferences.lua:1,12,18,23,29` | Beim Toggle ausdrücklich „für deine Charaktere“ erklären. Darstellungs-/Minimap-/Map-/Memberstatus-/PvP-Empfangseinstellungen werden ebenfalls geteilt; keine SV-Migration nötig, wenn nur UI umgeordnet |
| Main pro Realm+Fraktion | `Main.lua:52–73`, `Z.SetMain:106`; `AccountOverview.lua:mainFor:349` | Scope immer zeigen; SetMain nur im eingeloggten Scope; fremden Realm nicht still umhängen. Standardmain ist ältester gespeicherter Login im Scope, UI erklärt erste Speicherung |
| Öffentliches Main-/Alt-Linking begrenzt | `Main.lua:Z.PublicLinks:93` | Main publiziert max10 Alts desselben Scope; Alt publiziert nur Main. Sichtbarkeit und bestehende Transportfilter nicht umgehen; Hidden ist keine Privatsphäre-Freigabe |
| Fremde Main-Behauptungen sind keine Accountverifikation | `UXMemberGroups.lua:claimOf:34`, `altsContradict:58`, `build:82` | Scope, blocked, own-group Schutz, Widerspruch/Version/Zyklen/virtuelle Mainanker erhalten. Label „vom Addon angegeben“; unbekannte Main-Klasse nicht aus Twink kopieren |
| Private Kontakte | `Social.lua:scope:5`, `S.Initialize:16`; `SocialCategories.lua:1`; `SocialDiary.lua:1,48`; `CompanionTelemetry.lua:T.private:172` | Socialstore realm/faction-accountgeteilt, nicht global über alle Welten vermischen. Private Notizen/Favoriten sind nicht Communityöffentlich, können aber über separat explizit aktiviertes Companion-private-Topic exportiert werden; Kategorien und Diary sind davon getrennt. Daher niemals pauschal für alle privaten Funktionen „verlässt nie den Rechner“ behaupten. Keine neuen Exportfelder hinzufügen |
| Diary ist opt-in, keine Chatinhalte | `SocialDiary.lua:1,5,12`, `ObserveUnit:160`, `ObserveGroup:174` | Aufnahmeschalter und Quellen in Datenschutz auffindbar; Erklärung in Kontakte-Empty-State. Bestandsgrenzen 2000 Spieler,30 Ereignisse/Spieler,180 Tage Spielerretention,365 Tage Eventretention, geschützte bekannte/favorite/noted Datensätze berücksichtigen |
| Questlog-Sharing vs explicit request | `QuestHelper.lua:Q.Sharing:4`, `Q.Record:139`; `Main.lua:Z.ApplyQuest:364` | Gemeinsame-Quest-Daten erfordern consent+autoDiscovery+visible+shareQuests+identityReady und online Zustand. Explizite Anfrage/Hilfsangebot ist separate Geschäftslogik mit application/history/location/queue; nicht gleichsetzen |
| Inventar bleibt optionaler Snapshot | `AccountOverview.lua:O.ScanBags:209`, `O.ScanBank:216`, `O.OnEvent:228` | Bank nur beim Öffnen/on-event; kein Aktualisieren-Button, der Livebank aller Alts verspricht. Spielzeit nur vorhandenes `/played`, keine neue automatische Chatspam-Abfrage |

**Settings-Zuordnung:** `AccountOverview.SetEnabled` und `SetInventory` unter Einstellungen → Datenschutz und Freigaben → „Lokale Charakteraufzeichnung“ sichtbar machen; dieselben vorhandenen Aktionen zusätzlich im Datenstatus von Meine Charaktere erreichbar, kein zweiter Settingwert und keine geänderten Defaults/Scopes. Davon getrennt bleiben Communitysichtbarkeit und Companionexport. Overviewstore selbst wird nicht durch CompanionTelemetry referenziert; Companion erhebt aber eigenständige aktive-Charakter-Daten: Taschen (`CompanionTelemetry.lua:79`), Geld/Ausrüstung (`:112`), XP/rested (`CompanionViews.lua:124`). UI-Aussage deshalb präzise: „Diese gespeicherte Charakterübersicht wird nicht an die Community veröffentlicht“; optionalen Companionkanal mit eigenem Freigabestatus erläutern, statt globale Zusicherung „Niemals geteilt“.


## B. Empfohlene Informationsarchitektur

### B.1 Begründete Menüentscheidung

**E:** Acht Hauptbereiche: **Heute · Aktivitäten · Quests · Mitspieler · Handwerk · Handel · Meine Charaktere · Einstellungen**. Die vorläufige Nutzerstruktur ist nach dem Quellcodeabgleich sinnvoll: Questzusammenarbeit ist ein eigener dauerhafter Spielerbedarf und mehr als eine Aktivitätsart; Handwerk besitzt Rezept-/Auftragszustände, Handel dagegen Angebotslebenszyklen. Ein Zusammenlegen würde Aufgaben und Detailaktionen wieder mischen. Eigene Charaktere rechtfertigen wegen ihrer privaten Daten und häufigen Nutzung einen direkten Einstieg.

Nicht übernehmen würde ich vier permanente Aktivitäten-Unterseiten: „Meine Bewerbungen“ ist eine Sicht auf eigene Teilnahme, kein eigener Fachbereich. **Entdecken / Meine Aktivitäten / Geplant** reichen; „Organisiert / Bewerbungen“ sind Schnellfilter im persönlichen Bestand. Gefolgte Aktivitäten werden im Entdecken-Filter und unter „Folgen verwalten“ angeboten. Ein Klick auf eine Zeile zeigt Details und erlaubte Aktionen sofort. Das heutige zusätzliche „Öffnen“ entfällt in der breiten Ansicht.

Addon Manager ist kanonisch unter Einstellungen/Integrationen, mit der **bestehenden optionalen Hauptmenü-Abkürzung** entsprechend gespeichertem `showAddonManager`. Dies ist ein begründeter zusätzlicher Einstieg für häufige Addonnutzung; kein zweiter Manager. PvP-Hilfe und Glocke bleiben globale Kopfaktionen. Verlauf und Social Diary sind verschiedene Datenbestände; sie werden am Kontakt bzw. eigenen Aktivitätskontext geöffnet, nicht miteinander verschmolzen.

### B.2 Vorher-Sitemap – effektiver sichtbarer Aufbau

```text
ZENIAL-Hub / Compartment / /zenial
├─ Kopf: Glocke → Benachrichtigungen → Fachziel
│        PvP-Hilfe → Anfragen / Mein Hilferuf / Helfer
│        Discord → Kopierdialog
├─ Heute [9]
│  ├─ Wünsche → privater Wünsche-Editor (umgehängter SessionPlan)
│  ├─ gemischter Feed → gemeinsames Aktivitätsdetail-Modal
│  ├─ Gemeinsame Quests / Questgruppen → Quests [4]
│  └─ Aktivität erstellen → Typ/Zeit → Live-/Quest-/Termin-Details
├─ Aktivitäten [10]
│  ├─ Wann / Art / Alle-Organisiert-Bewerbungen / Suche
│  ├─ Liste → Vorschau → Öffnen → Aktivitätsdetail-Modal
│  ├─ Folgen → interne Gruppenansicht [3/follow]
│  ├─ Events → Terminübersicht [3/scheduled] → Editor/Serie
│  └─ Archiv → Archivdetail → Wieder erstellen / Archivieren bestätigen
├─ Quests [4]
│  ├─ Gemeinsame Quests → Quest / passende Spieler / Hilfe erstellen
│  └─ Questgruppen → Gruppe / Einladung / Entscheidung
│     (browse / mine / outgoing angelegt, Tabs versteckt;
│      Aufrufe über Fach-/Benachrichtigungspfade, nicht als normale Tabs)
├─ Mitspieler [1]
│  └─ Filter → Main-/Twinkliste → Profil, Notiz, Favorit, Kategorien,
│       Flüstern/Einladen, Kontakthistorie, Social Diary
├─ Handwerk [2]
│  ├─ Suche → Handwerker/Rezept → Herstellungsanfrage-Dialog
│  ├─ Meine Berufe/Rezepte → Scan / Berufshistorie
│  └─ Aufträge → Details / Aktionen / Alle Einkaufslisten
│       └─ Materialplanung (Tab versteckt) → Materialangebote → Handel
├─ Handel [5]
│  ├─ Angebote finden
│  ├─ Eigenes Angebot / Angebotseditor
│  ├─ Verwaltung → Live/Entwürfe/Pausiert/Abgelaufen/Vorlagen
│  └─ Suchalarme → Treffer / Regelaktionen
├─ Addon Manager [8, nur installiert + Option sichtbar]
│  └─ sechs horizontale Addon-Tabs → Providerpanel oder externer Fallback
└─ Einstellungen [11]
   ├─ Charakterprofil / Meine Charaktere / Darstellung / Verbindung → Profil [6]
   ├─ Addon Manager [8]
   ├─ Verlauf [7] → Zeitlinie / Löschbestätigung
   ├─ Companion → separates Setup / Einführung
   └─ Private Kontaktkategorien → Definitionseditor

Außerhalb: Weltkarten-Tracking/Pins, Join-Assistent, Verbindungübersicht,
Einladungslinks, Betreiber-/Katalogdialog, Diagnose/Backups, Beta-Hinweis,
Toasts/Todeshinweise/Versionshinweis, Launcher-Hub/Kommandos.
```

### B.3 Nachher-Sitemap – Aufgaben und eine Unterebene

```text
Global: Hauptnavigation immer sichtbar; Kopf: Glocke | PvP-Hilfe | Discord | X
├─ Heute (Standard nach Login)
│  └─ Offene eigene Aufgaben / jetzt relevante Aktivitäten / nächste Termine /
│     private Wünsche kompakt mit Bearbeiten; „Aktivität erstellen“ ist eine Aktion
├─ Aktivitäten
│  ├─ Entdecken [Standard] – Suche, Jetzt/Später, Typ, passend/gefolgt
│  ├─ Meine Aktivitäten – Organisiert / Bewerbungen als Filter
│  └─ Geplant – Termine, eigene Teilnahme, Serienaktionen am Termin
│     Auswahl → derselbe Detailbereich mit typabhängigen Aktionen
│     Archiv / Folgen / Vorlagen → kontextbezogene Arbeitsdialoge
├─ Quests
│  ├─ Meine Quests [Standard; tatsächlich geteilte/eigene Questliste]
│  ├─ Questhilfe – Alle / Meine Anfragen / Meine Hilfsangebote als Filter
│  └─ Questgruppen
│     Questauswahl → passende Spieler direkt daneben
├─ Mitspieler (Suche und Liste [Standard])
│  └─ Auswahl → Main + aktiver Charakter, öffentliche Infos,
│     private Notiz/Kategorien; Flüstern/Einladen; Chronikaktionen
├─ Handwerk
│  ├─ Finden [Standard] – Gegenstand/Beruf → Rezept + Handwerker
│  ├─ Aufträge – Eingehend / Ausgehend / Einkaufslisten als Filter
│  └─ Meine Berufe – eigene Rezepte, Scan und Berufshistorie
│     Anfrage → Materialien → Senden im selben Arbeitskontext
├─ Handel
│  ├─ Finden [Standard] – Suche/Angebote
│  ├─ Meine Angebote – Aktiv / Entwurf / Pausiert / Abgelaufen / Vorlagen
│  └─ Suchalarme – gespeicherte Regeln + Treffer
│     „Angebot erstellen“ immer sichtbar → Editor
├─ Meine Charaktere
│  ├─ Übersicht [Standard] – Auswahl + strukturierte private Daten
│  ├─ Gespeicherte Gegenstände – vorhandene Suchtreffer aus Taschen/Bank
│  └─ Öffentliches Profil – ausschließlich aktueller Charakter, Vorschau
│     Mehr: Main / Ausblenden / Löschen / Utility-Daten übernehmen
└─ Einstellungen
   ├─ Darstellung [Standard: Größe/Position und vorhandene Optionen]
   ├─ Datenschutz und Freigaben
   ├─ Community-Verbindung
   ├─ Benachrichtigungen (bestehender Empfang + Erklärung)
   ├─ Integrationen – Addon Manager, Companion
   └─ Erweitert und Diagnose – Bericht, Backups, Betreiberwerkzeuge

Optionaler gespeicherter Hauptmenü-Shortcut „Addon Manager“ bleibt möglich.
Separate Ausnahmeabläufe: Beitritt, Bestätigung, Kalender/Zeitwahl,
Import, Diagnosekopie, externe Addonoberfläche. Kein drittes Community-Menü.
```

### B.4 Verlustfreie Funktionszuordnung

Für jede Zeile ist die spätere Abnahme: alter Einstieg funktioniert als Alias, derselbe Datensatz wird angezeigt, dieselbe Fachaktion wird ausgeführt, Rücksprung erhält Filter/Selektion. Unterfilter zählen nicht als zusätzliche Unterseite.

| Bisherige Funktion / interner Besitzer | Künftiger kanonischer Ort / Direktaktion |
|---|---|
| Heute-Feed, Wunschabgleich, SessionPlans-Matches | Heute: offene eigene Aufgaben, jetzt relevante Aktivitäten, nächste Termine; Matching-/Spielertreffer bleiben im passenden Fachkontext erreichbar |
| Wünsche anlegen/ändern/aktivieren, Verfügbarkeit/Zeitraum | Heute: kompakte Wunschzusammenfassung; Bearbeiten öffnet bestehenden Editor, kein dauerhafter Formularbereich |
| LIVE-Gruppe finden / bewerben / zurückziehen | Aktivitäten/Entdecken → ausgewählter Eintrag |
| Eigene Livegruppe / Bewerber / Annehmen+Einladen / Ablehnen | Aktivitäten/Meine Aktivitäten → Organisiert → Detail |
| Ausgehende Gruppenbewerbungen, verlorener Organisator, Status | Aktivitäten/Meine Aktivitäten → Bewerbungen; gespeicherte Zeilen mit Datenlage |
| Aktivitäten folgen / entfolgen / neue Treffermeldungen | Aktivitäten/Entdecken → Gefolgt; Verwaltung als Kontextdialog |
| Geplante Termine entdecken / eigene Termine / Teilnahme | Aktivitäten/Geplant mit Besitz-/Teilnahmefilter |
| Termin anlegen / bearbeiten / absagen, Teilnahme bestätigen/ablehnen/Warteliste | „Aktivität erstellen“ bzw. Termin-Detail; ScheduledGroups bleibt Autorität |
| bestätigte Teilnehmer einzeln / alle einladen | Termin-Detail, bestehende Rechte-/Online-/Revisions-/Dedupeprüfungen |
| Serien / Wiederholung / nächste Termine | Termin-Kontext „Serie“ im vorhandenen Serienworkflow |
| Aktivitätsarchiv / frühere Inhalte / Wieder erstellen | Aktivitäten → Archivdialog; Typ/Revision bleibt erhalten, Wiedererstellen öffnet Editor |
| Archivieren eigener Live-/Quest-/Terminaktivität | Detail → Mehr/Archivieren → konkrete Bestätigung |
| Gruppen-/Aktivitätsvorlagen, Name/Zeitraum speichern | Composer → Vorlage; bestehender Vorlagenbestand bleibt |
| Sofortaktivität vs geplante Aktivität / Typauswahl | ein Composer-Einstieg, maximal zwei fachliche Formularschritte |
| Gemeinsame/eigene Quests / Questkategorien / Such- und Zonenfilter | Quests/Meine Quests; vorhandene Sharing- und Abgleichbedingungen erklären |
| passende Questmitspieler / Fortschritt / Flüstern / Einladen | direkt an ausgewählter Quest; kein erneuter Mitgliederfilter nötig |
| Questhilfe fremd / selbst / eigene Angebote | Quests/Questhilfe über Besitz-/Teilnahmefilter, zusätzlich Aktivitäten-Projektion |
| Questhilfe erstellen/bearbeiten / Bewerber / Gruppenbildung | Questkontext bzw. Composer, gleiche QuestHelper-/Main-Funktionen |
| Questgruppen / lokale Vorschläge / Abdeckung / Mitglied auswählen / einzeln einladen | Quests/Questgruppen → Detail; QuestGroups bleibt zuständig |
| PvP-Hilfe senden / Vorschau / eigene Anfrage schließen | Kopfaktion → eigener Hilferuf mit bestehenden Voraussetzungen |
| PvP-Aufrufe / Hilfe zusagen/zurückziehen / Helfer ansehen/einladen | Kopfaktion → PvP-Ansicht, zusätzlich Aktivitäten-Typfilter |
| PvP-Empfang / Zone / Todeshinweise / Karten-Todespunkt | PvP-Kontext; derselbe Empfangswert in Einstellungen erläutert; Karte bleibt eigenständig |
| Mitspielersuche, Online/Klasse/Beruf/Gilde/Favoriten/Kategorie/Sortierung | Mitspieler: Suche + wenige Schnellfilter + Erweitert |
| Main-/Twink-Gruppierung / Aufklappen / aktiver Char | Mitspielerliste; stabile Mainidentität mit sichtbarer aktiver Aktionsempfänger-Zeile |
| Mitgliedprofil / Profilabruf / Freigaben / Standort/Layer | Mitspieler-Detail; unbekannt/alt/verborgen differenzieren |
| Favorit / private Notiz / Kategoriezuordnung / Blockieren soweit vorhanden | Kontakt-Detail mit bestehender Zielschlüssel-Semantik; nichts auf Main umschreiben |
| Kategoriedefinitionen hinzufügen/umbenennen/löschen | Mitspieler → Kategorien verwalten; Settings-Link als erklärbarer Quereinstieg |
| private Kontakthistorie / Finderzeitlinie / Verlauf löschen | Kontakt → Verlauf; unfiltrierter Verlauf zusätzlich Aktivitäten → Verlauf |
| Social Diary / Kontakteinträge / Sitzungen / Filter / Notiz | Kontakt → Social Diary; `/zenial diary` weiterhin Zielkontakt |
| Gegenstand/Rezept/Beruf suchen / Handwerkerliste / Favorit / Flüstern | Handwerk/Finden; Ergebnis + Rezeptdetails zusammen |
| Herstellungsanfrage / Menge / Nachricht / Materialoption | Handwerk/Finden → Anfragepanel mit Materialprüfung |
| eingehende/ausgehende Aufträge / Statusaktionen / Handoff | Handwerk/Aufträge; bestehende CraftOrders-Zustandsmaschine |
| eigene Berufe/Rezepte / Scan-/Vollständigkeitsstatus / Berufshistorie | Handwerk/Meine Berufe; Aktualisieren erklärt erforderliches Berufsfenster |
| private Materiallisten / auftragsgebundene Planung / Reservierungen / manuell markieren / löschen | Handwerk/Aufträge → Einkaufslistenfilter, Liste+Materialdetail |
| Materialangebote finden / auswählen / Herstellungsanfrage fortsetzen | verknüpftes Handelsdetail mit explizitem Rücksprungkontext |
| Angebote suchen / Filter / sortieren / Flüstern | Handel/Finden; keine automatische Kauf-/Chataktion |
| eigenes Angebot erstellen/bearbeiten/veröffentlichen/schließen | Handel → „Angebot erstellen“ bzw. Meine Angebote → Detail/Editor |
| Entwürfe / pausiert / erneutes Veröffentlichen / abgelaufen | Handel/Meine Angebote über Zustandsfilter |
| Handelsvorlagen speichern/öffnen/löschen | Handel/Meine Angebote → Vorlagenfilter oder Composer-Vorlage, ein Datenbestand |
| Suchalarme / gespeicherte Suchen / ein-aus / löschen / Treffer | Handel/Suchalarme; gespeicherte Suchregel bleibt TradeManager-Regel |
| eigene Charaktere suchen / Realm-/Fraktionsfilter / versteckte zeigen | Meine Charaktere/Übersicht |
| Main setzen / ausblenden / wieder einblenden / löschen | Charakterkopf + Mehr; gleiche Utility/current/sameScope-Prüfungen |
| Gold / EP-Erholung / Spielzeit / Berufe / Speicher-/Importherkunft | Übersicht als Infoabschnitte mit Zeitstempeln |
| Taschen/Bank / Gegenstandssuche / aufbewahrte Mengen | Meine Charaktere/Gespeicherte Gegenstände; Suchtreffer mit Holder und Taschen-/Bankmengen. Kein Inhaltsbrowser, keine Slots und keine neue Lagerortfilterfunktion |
| Accountaufnahme / Inventaraufnahme / Utility-Übernahme | bestehende Aufnahmeoptionen klar getrennt von öffentlichem Teilen; Utility-Aktion bewusst auslösen |
| Anzeigename / bevorzugte Rolle / Profilnotiz / öffentliche Vorschau/Speichern | Meine Charaktere/Öffentliches Profil, immer eingeloggter Charakter |
| öffentliche Sichtbarkeit / Berufe und Rezepte teilen | Einstellungen/Datenschutz; öffentlicher Profileditor zeigt aktuellen Freigabestatus |
| Anzeige-/Fensteroptionen / Position-/Größenreset | Einstellungen/Darstellung |
| Community-Status / Refresh / Einladung / Join | Einstellungen/Community-Verbindung; Join-Banner bleibt global relevant |
| Betreiber-Lounges / Paarwahl / Katalog-Import-/Export / Transporttests | Einstellungen/Erweitert und Diagnose → vorhandener Technikdialog |
| Diagnosen / Backups samt Bestätigung | Einstellungen/Erweitert und Diagnose; Slash-Aliase unverändert |
| Companion-Setup / Einführung / Export / Questflächen / Download / Technikstatus | Einstellungen/Integrationen → Companion; bestehende Slash-/Joinwege |
| Addonversion / Status / Beschreibung / Öffnen / externe Legacyoberfläche | Einstellungen/Integrationen → derselbe Addon Manager; optionaler Hauptshortcut |
| Glocke / Fach-Unread / Toasts / Versionshinweis | Kopf und bestehende globale Karten, einheitliche Fachzielauflösung |
| Discord / Beta-Hinweis / Minimap/Compartment / Weltkartenoverlay | bestehende globale/bedingte Einstiege; keine Zwangsverlagerung in Hauptmenüs |

## C. Text-Wireframes und Interaktionsverhalten

**E – gemeinsame Hülle:** links sichtbare acht Bereiche, rechts Inhaltsfläche. Oben Titel und höchstens eine Primäraktion, darunter eine Unteransichtszeile, dann Suche/Filter, Liste und Detail. Die Hülle bleibt auch bei Detaildialogen sichtbar. Ausnahmen bei externen nativen Fenstern/Addonprovidern sind ausdrücklich bezeichnet. Wireframes zeigen Anordnung, keine finalen Grafiken oder neuen Datenfelder.

### C.1 Heute

```text
+------------------+--------------------------------------------------------+
| ZENIAL           | Heute                         [Glocke] [PvP] [Discord] X|
| > Heute          +--------------------------------------------------------+
| Aktivitäten      | Für dich jetzt                     [+ Aktivität]       |
| Quests           | Wünsche (privat): Dungeon … · Quest … [Bearbeiten]     |
| Mitspieler       |--------------------------------------------------------|
| Handwerk         | OFFENE EIGENE AUFGABEN                                  |
| Handel           | 2 Bewerbungen offen / Auftrag bereit       [Ansehen]   |
| Meine Charaktere | eigene Aktivität mit Handlungsbedarf       [Verwalten] |
|                  |--------------------------------------------------------|
| Einstellungen    | JETZT RELEVANTE AKTIVITÄTEN                              |
|                  | Titel · Typ · Rollen · passender Grund      [Details] |
|                  | weitere kurze Treffer              [Alle Aktivitäten] |
|                  |--------------------------------------------------------|
|                  | NÄCHSTE TERMINE                                         |
|                  | Uhrzeit · Titel · eigene Teilnahme          [Details] |
|                  | keine Termine: verständlicher Leerzustand               |
+------------------+--------------------------------------------------------+
```

Nur diese drei Inhaltsbereiche; je Vorschau höchstens drei Zeilen und ein Fachlink. Offene Aufgaben werden aus vorhandenen Aktivitäts-/Bewerbungs-/Auftragszuständen abgeleitet, nicht aus einer neuen Aufgaben-Domain. Jetzt relevant nutzt bestehende Zeit-/Matchlogik mit erkennbarem Grund; nächste Termine zeigen vorhandene Termine/Teilnahmen. Keine zusätzliche große Rubrik „Passende Mitspieler“ und kein allgemeiner endloser Feed. Spieler-/Wunschmatching und Questeinstiege bleiben über vorhandene Fachansichten/gezielte Links erhalten.

Wünsche sind standardmäßig eine kurze, umbrechbare Zusammenfassung. „Bearbeiten“ öffnet den vorhandenen begrenzten Wunschdialog; vorhandenes Limit, Privatheit, Validierung, explizites Speichern/Löschen und Revision-/Eingabeschutz bleiben. Ein späterer kompakt eingeklappter Editor wäre erst bei nachgewiesenem Bedarf zu prüfen; kein Inlineeditor ist für dieses Redesign erforderlich. Bei wenig Höhe bleiben Titel, Wunschzusammenfassung und offene Aufgaben zuerst sichtbar; Aktivitäten und Termine sind im einen Inhalts-Scroll erreichbar. Die Änderung behauptet keinen Klickgewinn bei der Wunschbearbeitung; J17 bleibt beim bestehenden Weg.

### C.2 Aktivitäten

```text
Aktivitäten                                            [+ Aktivität erstellen]
[Entdecken] [Meine Aktivitäten] [Geplant]                   [Archiv] [Mehr v]
[Suche........................] [Jetzt v] [Art v] [Erweiterte Filter]
+--------------------------------+--------------------------------------------+
| Titel · Organisator · Art      | Ausgewählte Aktivität · LIVE/QUEST/EVENT/PVP|
| Rollen / Uhrzeit / Status      | Zeit, Ort, Gruppe, Datenalter, Nachricht   |
| > ausgewählte Zeile            | Eigene Teilnahme / Freie Rollen            |
| weitere Ergebnisse             | ------------------------------------------ |
|                                | eigener Termin: Teilnehmerliste + Status   |
|                                | [Bestätigen] [Warteliste] [Einladen]        |
|                                | fremd: Rolle [v] Nachricht [...]            |
|                                | [Bewerben] [Zurückziehen] [Flüstern]         |
|                                | [Bearbeiten] [Mehr v] nur wenn berechtigt   |
+--------------------------------+--------------------------------------------+
Meine Aktivitäten: [Alle] [Organisiert] [Bewerbungen]  (Filter, keine neue Seite)
```

Nur passende Aktionsgruppe sichtbar, keine gleichzeitige Wand aus sämtlichen Buttons. Fehlende Berechtigung mit verständlichem Grund, keine zusammengeführte neue Zustandsmaschine. Schmale Ansicht: Auswahl ersetzt Liste im gleichen Inhaltsbereich, oben „Zurück zu Ergebnissen“; Auswahl/Scroll/Filter bleiben. Composer startet als begrenztes Arbeitsmodal, Archiv/Serien bleiben kontextbezogene Aufgaben.

### C.3 Quests

```text
Quests                                                  [+ Hilfe anfragen]
[Meine Quests] [Questhilfe] [Questgruppen]
[Quest oder Gebiet suchen................] [Aktuelle Zone] [Erweitert]
+--------------------------------+--------------------------------------------+
| Gebiet (aufklappbar)            | Questtitel · Level · Fortschritt           |
| > Quest · 3 passende Spieler   | „Gemeinsam im Questlog“ / „Hilfeanfrage“    |
| Quest · keine passenden Daten  | ------------------------------------------ |
| weiteres Gebiet                | PASSENDE SPIELER                           |
|                                | Name · Fortschritt · online · Datenalter   |
|                                | [Flüstern] [Einladen]                       |
|                                | [Questgruppe bilden] [Hilfe anfragen]      |
+--------------------------------+--------------------------------------------+
Questhilfe: [Alle] [Meine Anfragen] [Meine Hilfsangebote] → gleiches Detailschema
```

Gleichzeitiger Questbesitz ist keine Bewerbung. Hilfsangebote/Anfragen tragen ausdrücklich diese Benennung; Erstellen publiziert erst nach vorhandener Formularbestätigung. Bei fehlender Freigabe erklärt die leere Ansicht den Grund und bietet den vorhandenen Datenschutzweg.

### C.4 Mitspieler

```text
Mitspieler
[Name / Main / Twink suchen..................] [Online] [Favoriten] [Meine Gilde]
[Erweiterte Filter v]                         [Kategorien verwalten]
+--------------------------------+--------------------------------------------+
| [Klasse] Mainname        online | Mainname · Klasse · Main                   |
|   spielt gerade: Twinkname      | Aktiv: Twinkname · Ort · Layer · Alter      |
|   [v] 2 weitere Charaktere      | [Twinkname anflüstern] [Twinkname einladen] |
| Spieler 2                      | ------------------------------------------ |
|                                | Öffentlich: Rolle / Notiz / Berufe          |
|                                | Privat: [Favorit] [Kategorien...]            |
|                                | [Eigene Notiz........................]      |
|                                | [Notiz speichern]                          |
|                                | [Kontakthistorie] [Social Diary]            |
+--------------------------------+--------------------------------------------+
Erweitert: Klasse [v] Beruf [v] Kategorie [v] Sortierung [v] Gruppieren [x]
```

Main bleibt die Erkennungsidentität, der aktive Charakter das sichtbare Aktionsziel. Bei expliziter Einzelcharakterauswahl gilt dieser Charakter; nie still auf aktiven Twink umleiten. Private Markierungen nicht zusammenlegen. Keine Aktion nur über Rechtsklick erreichbar; Mehrmenü ist zusätzlich per normalem Klick offen.

### C.5 Handwerk

```text
Handwerk
[Finden] [Aufträge] [Meine Berufe]
[Gegenstand oder Rezept suchen..............] [Beruf v] [Online] [Erweitert]
+--------------------------------+--------------------------------------------+
| Rezept / Gegenstand            | Gegenstand · Beruf · Rezeptdatenstatus      |
| > Rezept                       | HANDWERKER: [Name / online / Datenalter v] |
|   passende Handwerker: 3       | ------------------------------------------ |
|                                | MATERIALIEN          benötigt / vorhanden   |
|                                | Erz                   10 / 6    fehlt 4     |
|                                | [Einkaufsliste speichern] [Angebote ansehen] |
|                                | ANFRAGE: Stückzahl [1] · Craftvorgänge [1]          |
|                                | [ ] Materialien werden gestellt             |
|                                | [Herstellungsanfrage senden]                |
+--------------------------------+--------------------------------------------+
Aufträge: [Eingehend] [Ausgehend] [Einkaufslisten] → Liste + Fachdetails
```

Trinkgeld und Nachricht bleiben als vorhandene Anfragefelder erreichbar. Community-Rezeptsuche wird weiterhin bewusst per Suchen/Enter ausgelöst; lokales Filtern und Remote-Suche werden nicht gleichgesetzt. Materialanzeige verwendet vorhandene Bag-only-/Reservierungslogik, nicht Account-Bankdaten als live verfügbare Materialien. „Unvollständig/unbekannt“ ist ein Datenzustand, nicht Menge null. Ausflug zum Handelsangebot erhält Rezept, Handwerker, Menge, Eingaben, Listen-ID und Rückkehrpunkt im RAM; Rückkehr prüft Fachobjekte neu.

### C.6 Handel

```text
Handel                                                   [+ Angebot erstellen]
[Finden] [Meine Angebote] [Suchalarme]
[Gegenstand........................] [Kaufen/Verkaufen v] [Erweiterte Filter]
+--------------------------------+--------------------------------------------+
| Gegenstand · Menge · Stückpreis| Gegenstand · Anbieter · Art                 |
| > Angebot                      | Menge / Stück- und Gesamtpreis              |
| Gültig bis / Datenstatus       | Restlaufzeit / Hinweis / Erreichbarkeit     |
| weitere Angebote               | [Flüstern] [Suchalarm aus Suche]            |
|                                | eigener Eintrag: [Bearbeiten] [Pausieren]   |
|                                | [Erneut anbieten] / [Schließen] nach Zustand|
+--------------------------------+--------------------------------------------+
Meine Angebote: [Aktiv] [Entwürfe] [Pausiert] [Abgelaufen] [Vorlagen]
Materialkontext: „Für Einkaufsliste X – 4 fehlen“ [Zurück zur Herstellung]
```

Filter für Kategorie, Preisgrenzen und Sortierung erst unter Erweitert; aktive Filterzusammenfassung bleibt sichtbar. Angebotseditor als Aktion, nicht Tab. Pausieren/Veröffentlichen/Alarmaktivierung bleiben bewusste Klicks mit vorhandenen Ablaufregeln.

### C.7 Meine Charaktere – Alternative A: Auswahl plus Charakterblatt (empfohlen)

```text
Meine Charaktere                                         Privat gespeichert [i]
[Übersicht] [Gespeicherte Gegenstände] [Öffentliches Profil: aktueller Charakter]
[Charakter suchen.........] [Realm v] [Fraktion v] [Ausgeblendete anzeigen]
+-----------------------------+-----------------------------------------------+
| [Icon] Name · Lv60 · MAIN    | [Klassenicon] Name · Lv60 · Klasse · Realm     |
| Realm · Fraktion · aktuell  | Fraktion · MAIN/TWINK · aktuell/zuletzt gesehen|
| [Icon] Twink · Lv42          | [Als Main festlegen] [Mehr v]                  |
| Realm · Fraktion            |-----------------------------------------------|
| weitere Charaktere          | GOLD                  ERHOLUNGS-EP             |
|                             | 123g 45s 6k           [Fortschritt] exakt/Wert  |
|                             |-----------------------------------------------|
|                             | SPIELZEIT             BERUFE                   |
|                             | Gesamt / dieses Level Schmiedekunst 225/300    |
|                             |                       Erste Hilfe ...          |
|                             |-----------------------------------------------|
|                             | TASCHEN               BANK                     |
|                             | gespeicherter Stand   zuletzt geöffnet ...     |
|                             | Aufnahme/Stand        Aufnahme/Stand          |
|                             |-----------------------------------------------|
|                             | Daten: Zeit pro Bereich / Quelle / veraltet    |
+-----------------------------+-----------------------------------------------+
Aufnahme: an/aus · Inventar: an/aus [Aufnahmeoptionen]  (keine Freigabeoption)
Mehr: Aus-/Einblenden · Daten löschen… · Utility-Daten übernehmen
```

**E – Vorteile:** vertraute Charakterauswahl, Main-/Aktivkennzeichnung sichtbar, verschiedene Datentypen bekommen eigene Darstellung, Offlinecharaktere klar getrennt. Gut mit vorhandenem `AccountOverview.Rows/Stats/Search` und bestehender Auswahl kompatibel. **Nachteile:** accountweiter Vergleich benötigt Charakterwechsel; bei wenig Breite muss das Blatt die Liste ersetzen. **Empfehlung:** A als Standard, weil primär ein Charakter verstanden und verwaltet werden soll; Datenfläche wird grundlegend in Abschnitte umgebaut, nicht nur neu eingefärbt.

Erholungsbalken nur bei vorhandenem sinnvollem Nenner; keine geschätzten Offline-EP als aktuell gemessene Werte darstellen. Berufe je nach Anzahl umbrechen. Gold/Spielzeit als Werte mit Beschriftung, Inventar/Bank als Datensnapshot mit Zeit, nicht als gleichwertige Textzeilen einer Auswahlliste. Aufnahme-/Inventarschalter bleiben dieselben lokalen Optionen; Erfassung aus entspricht nicht Datenlöschung.

### C.8 Meine Charaktere – Alternative B: kompakte Accounttabelle mit aufgeklapptem Blatt

```text
Meine Charaktere    [Übersicht] [Gespeicherte Gegenstände] [Öffentliches Profil]
[Suche...] [Realm v] [Fraktion v] [Ausgeblendete]                  Privat
+-------------------------------------------------------------------------+
| Charakter / Klasse | Realm | Level | Gold | Erholung | letzte Aktualisierung|
| > Mainname [MAIN]  | ...   | 60    | ...  | ...      | ...                  |
|   Twinkname        | ...   | 42    | ...  | ...      | ...                  |
+-------------------------------------------------------------------------+
| AUSGEWÄHLTER CHARAKTER: Kopf + [Main] [Mehr]                              |
| Spielzeit          | Berufe                 | Taschen/Bank-Stand          |
| Quelle/Alter       | strukturierte Skills   | gespeicherte Summen       |
+-------------------------------------------------------------------------+
```

**E – Vorteile:** accountweiter Vergleich von Level/Gold/Erholung ohne Auswahlwechsel; viele Charaktere gut scanbar, vorhandene Aggregationen nutzbar. **Nachteile:** Tabellenbreite, lange Realm-/Charakternamen, mehr Spaltenausblendung; Datenheterogenität und Unbekanntwerte schwerer lesbar; auf 900×610 geht der Vergleichsvorteil verloren. B ist eine echte alternative Grundstruktur, kein zweites Farbthema. **Entscheidung:** A ist gewählt. B bleibt ausschließlich historische Vergleichsalternative und wird nicht zur erneuten Layoutentscheidung gestellt oder zusätzlich implementiert. Kein optionaler Tabellenmodus als unerbetenes Zusatzfeature.

### C.9 Gespeicherte Gegenstände und öffentliches Profil (klare Scopegrenze)

```text
Gespeicherte Gegenstände – Suche in vorhandenen Taschen-/Bankaufzeichnungen
[Name ab 2 Zeichen oder Item-ID..................]  Realm/Fraktion: wie Übersicht
Leere Suche: Suchhinweis, keine vollständige Liste des gespeicherten Inhalts
+--------------------------------+--------------------------------------------+
| Gefundener Gegenstand · Gesamt | HOLDER DES SUCHTREFFERS                     |
| > Suchtreffer                  | Charakter · Realm/Fraktion                   |
| weitere Treffer (max. 50)       | 4× Taschen · 8× Bank · Stand/Herkunft        |
|                                | Namen laden noch / keine Aufzeichnung       |
+--------------------------------+--------------------------------------------+
[Zur Charakterübersicht]                Kein Vollinventar-/Bankbrowser

Öffentliches Profil – eingeloggter Charakter NAME (nicht Listen-Auswahl)
Anzeigename [...]  Rolle [v]          VORSCHAU DES ÖFFENTLICHEN PROFILS
Profilnotiz  [...]                    Name / Rolle / Notiz / Freigabestatus
[Speichern] [Bei Mitspielern ansehen] [Datenschutz und Freigaben]
```

**B:** `AccountOverview.Search:434–465` liefert Itemtreffer mit Gesamtmenge und Holdermengen aus gespeicherten Taschen-/Bankdaten, keine Slots oder vollständige Inventaransicht. Mindestabfrage zwei Zeichen oder numerische Item-ID, Trefferlimit und asynchrones Namensauflösen bleiben erhalten. Die UI begrenzt den Suchbestand heute über Realm/Fraktion/ausgeblendete Charaktere (`AccountOverviewUI:71–95`); diese Scopefilter werden in der neuen Suchansicht ausdrücklich angezeigt und weiterverwendet, nicht heimlich erweitert. Namenssuche nach Charakteren und Itemabfrage sind getrennte Eingaben, ohne neue Suchsyntax oder neue Backendfilter.

**E:** „Gespeicherte Gegenstände“ ist eine eigenständig lesbare **Suchergebnisansicht**, kein Browser. Keine Anzeige aller Inhalte bei leerer Suche, kein Taschen-/Bank-Slotraster, kein neuer Einzelcharakter-/Lagerortfilter, keine Itemaktionen, keine Livebankabfrage. Im Charakterblatt bleiben bestehende Taschen-/Banksummen und Erfassungszeiten als Informationsblöcke; „Inventar ansehen“ oder „Bank ansehen“ entfallen als irreführende Browseraktionen. Quelle/Alter nur aus vorhandenen Daten ableiten; fehlende Daten nicht zu null vervollständigen.

Öffentliche Vorschau liest ausschließlich bereits öffentliche Felder. Gold, Bank, Spielzeit und private Importquelle erscheinen darin nicht. Der Companionhinweis beschreibt den separaten optionalen Export, ohne öffentliche Freigabe damit gleichzusetzen.

### C.10 Einstellungen

```text
Einstellungen                 [Darstellung | Datenschutz | Community |
                               Benachrichtigungen | Integrationen | Erweitert]
+-------------------------------------------------------------------------+
| DARSTELLUNG                                                               |
| Fenstergröße: aktueller Wert     [Standardgröße] [Position zurücksetzen]   |
| vorhandene Karten-/Launcheroptionen: erklärt am zuständigen Besitzer       |
|-------------------------------------------------------------------------|
| DATENSCHUTZ (bei dieser Kategorie anstelle des obigen Abschnitts)           |
| [x] Öffentliches Profil sichtbar           Wirkung in einem Satz           |
| [x] Berufe und Rezepte teilen               Wirkung in einem Satz           |
| Keine weiteren internen Freigabewerte als neue Schalter                    |
| Private Charakteraufnahme [vorhandener Wert]  keine öffentliche Freigabe    |
|-------------------------------------------------------------------------|
| COMMUNITY: Verbunden / Prüfen / Beitreten / [Einladungslink]                |
| Technik nur in „Erweitert“                                                |
+-------------------------------------------------------------------------+
```

Es wird immer nur die gewählte Kategorie angezeigt; Wireframe zeigt exemplarisch deren Inhaltsanordnung. Auf schmalen Fenstern Kategorienauswahl als ein Dropdown mit aktuellem Namen, keine zweite Sidebar innerhalb der ersten. Keine leere Kategorie „Allgemein“ oder Platzhalterregler nur für Symmetrie. Nur die in A.4 als tatsächlich bedienbar belegten Controls werden übernommen. Karten-/Slash-/Fachkontextoptionen erhalten ihre bisherigen Bedienorte; Settings darf darauf verweisen, erzeugt aber keine zusätzlichen Schalter. Diagnose und Integration dürfen bestehende eigenständige Spezialdialoge öffnen; Rückkehr endet in derselben Settingskategorie.

### C.11 Addon Manager

```text
Integrationen / Addon Manager                             [Zurück zu Integrationen]
+-----------------------------+-----------------------------------------------+
| INSTALLIERT                 | Utility · Version ... · Geladen               |
| Crit       v...   Bereit    | Kurzbeschreibung                              |
| GunSound   v...   Bereit    | [Oberfläche öffnen] / eingebetteter Provider   |
| DevLogger  v...   Deaktiv.  |-----------------------------------------------|
| ClassFrames ...             |                                               |
| Watch ...                   | vorhandene Addonoberfläche / Providerhost      |
| > Utility ...               | deren eigene Einstellungen bleiben unverändert |
|-----------------------------|                                               |
| WEITERE ZENIAL-ADDONS        | Fehlerzustand: verständlicher Grund und         |
| Nicht installiert ...       | bisheriger externer Slash-Fallback, falls da   |
+-----------------------------+-----------------------------------------------+
```

Bei eingebetteter Oberfläche kann die Liste während der Bedienung zu einem kompakten Auswahlkopf werden, um dem Provider die bisherige Hostfläche zu lassen. Hauptnavigation bleibt sichtbar; ein Provider darf eigene Menüs enthalten. Fehlende Addons werden erklärt, nicht installiert. Status/Version bleiben im Managerkontext erkennbar, statt im gekürzten Tabtitel unterzugehen.

## D. Gemeinsames Komponenten- und Interaktionssystem

### D.1 Wiederverwenden und gezielt ergänzen

| Komponente | Vorhanden / Entscheidung | Einheitlicher Vertrag |
|---|---|---|
| Hülle, Palette, Schrift, Icons | Theme.lua `Shell/Panel/Text/Tint`, Community-Skin; unverändert als Basis | „stone and gold“, vorhandene benannte Farben; keine neue Palette pro Seite |
| Buttons/Navigation/Chips | `T.Button/StyleButton/StyleNav/StyleTab/Chip`, `S.button/navButton/selectNav` | Primär = eine wichtigste Aktion, Sekundär = neutral, Gefahr = vorhandener Danger-Stil; Auswahl nicht mit Deaktivierung verwechseln |
| Listen/Zeilen | `S.list/rows`, `T.StyleRow/UpdateRow`, variable Höhen und Recycling vorhanden | explizite selected-/key-Zustände, max. zwei Textzeilen für Hauptlisten, keine Aktionshandlersammlung pro Refresh neu erzeugen |
| Suche/Dropdown/Check | `S.edit/selector/checkbox`, Item-Suggestions, Popupbreite, Tabchain | bestehende Validierung und kanonische Werte; sichtbare Labels, aktive Filterzusammenfassung |
| Leere-/Lade-/Fehlerzustände | `U.SetEmptyHint`, vorhandene Rezept-/Profilabrufzustände | „Keine Treffer“, „Daten werden angefragt“, „Nicht freigegeben“, „Veraltet“, „Nicht unterstützt“ getrennt; kein leeres Rechteck |
| Status/Feedback | `U.Message/Toast`, `NoticeUI.NewNotice`, Notifications | sofortige Rückmeldung im Aktionskontext; gesendet ≠ bestätigt ≠ abgeschlossen |
| Dialog/ESC/Schließen | `UI.CloseButton`, `S.makeModal`, `CloseDialogs`, Keyboard-/Combat-Schutz | Schließen beendet Sichtbarkeit; explizites Verwerfen beendet Arbeitskontext; Chatfreigabe vor nativer Fokussierung |
| Formulare/Kalender | `FormLayoutUI`, `SchedulePickersUI` | bestehende Zwei-Schritt-Komposition und Feldvalidierung; Pflichtfelder/Fehler am Feld plus verständliche Zusammenfassung |
| Listen-/Detailaufteilung | bisher manuell pro Seite / CompactArea | E: zuerst konkret in Charakterlayout A/P3 auf vorhandenen Helpers erproben; `SplitView` erst bei zweitem passenden Verbraucher nach Abgleich extrahieren, keine P1-Pflicht |
| Aktionsleiste | bereits ActivityDetails/Domain-Buttons, noch nicht gemeinsam abstrahiert | E: bestehende Buttons/Handler verwenden; gemeinsame `ActionBar` nur bei belegter Wiederholung ab P5a, Fachhandler bleiben je Typ zuständig |
| Charakterwert / Abschnitt / Aktualitätszeile | bisher Textzeilen in AccountOverviewUI | E: lokale kleine Layouthelfer in P3 nur für tatsächlich benötigte Werttypen; `InfoSection/Metric/Freshness` sind mögliche Extraktionen nach Referenzabnahme, kein vorab zu bauendes Paket |
| Filterbereich | existierende Controls, feste Positionen | E: in P3 vorhandene Filter umordnen, danach P4-Bedarf abgleichen; `FilterBar` nur bei tatsächlicher gemeinsamer Layoutlogik extrahieren, keine zweite Filterlogik |

### D.2 Konkrete Gestaltungsregeln (E)

- **Abstände:** Raster 8 logische UI-Pixel, Abschnittsabstand 16, Inhaltsrand 16, zugehörige Label-/Wertabstände 4–8. Keine Verschachtelung mehrerer dekorativer Panels. Auswahlleiste gold, Status zusätzlich in Text.
- **Schrift:** vorhandene FontObjects wiederverwenden. Haupttext Ziel 13–14, Nebeninfo 12, Überschrift 16–18 bei Benutzer-Scale 1; niemals automatisch unter die gewählte Schriftgröße schrumpfen. Bei anderen UI-Scales im Client auf tatsächliche Lesbarkeit prüfen.
- **Listen:** kompakte Einzeile mindestens 32, normale Zweizeile 44–48, Quest/Material mit begründetem Zusatz 56–64. Namen, Art und Status zuerst, technische Identitäten nur im Diagnosekontext. Klassenicon 20–24, nicht jedes Feld erhält ein Icon.
- **Auswahl:** exakt ein stabiler Datensatzschlüssel; Hintergrund und Marker, nicht nur Schriftfarbe. Eine laufende Aktualisierung darf Fokus/Scroll/Selektion nicht zurücksetzen. Verschwundener Datensatz wird erklärt, niemals auf den nächsten Eintrag mit anderer Identität umgedeutet.
- **Aktionen:** wichtigste erlaubte Aktion am Detail; maximal zwei direkt sichtbare gleichrangige Sekundäraktionen, Rest im per Klick zugänglichen Mehrmenü. Zerstörerische Aktionen getrennt, Bestätigung nennt Objekt und tatsächliche Folgen. Deaktiviert zeigt einen konkreten Grund per Text/Tooltip und bleibt erreichbar erklärbar.
- **Suche/Filter:** Textsuche ohne zusätzlichen Suchen-Klick, wo Backend bereits lokal filtert; Remote-Rezeptabfragen weiterhin vorhandenes kontrolliertes Timing. Nicht bei jedem Keypress alle Fachmodule refreshen. Dropdown öffnet mit einem Klick, Auswahl kostet einen weiteren; diese Interaktionen in Messungen mitzählen.
- **Formulare:** keine versteckten Pflichtfelder; Platzhalter ersetzt kein Label. Bestehende Zeichen-/Zahlen-/Zeitgrenzen erhalten. Validierung verwirft Eingaben nicht. Abbrechen/Zurück/Speichern klar unterscheiden; keine neue Entwurfpersistenz für Aktivitätsformulare einführen.
- **Rückmeldungen:** lokal gespeichert, Veröffentlichung gesendet, Antwort ausstehend, bestätigt und beendet sprachlich unterscheiden. Netzwerkverzögerung im betroffenen Detail zeigen, globale Toasts sparsam. Kein automatisches Publizieren bei Vorschau/Filterwechsel.
- **Veraltete Daten:** Snapshotzeit pro Bereich und Quelle anzeigen; fehlende Bankdaten heißen „Noch nicht erfasst“, nicht „leer“. Unvollständige Rezeptmaterialien heißen unvollständig; manuell markiert heißt nicht im Besitz/übergeben.
- **Zurück:** Detail→vorherige Liste, Arbeitsausflug→vorheriger Kontext; Hauptmenüwechsel bleibt direkt möglich. Breadcrumb nur bei Quellenklärung (z. B. Materialliste→Angebot), keine dekorative Dreiebenenpfade.
- **Sprache:** alle neuen Texte über Locale; technische Enumwerte nicht direkt anzeigen. DE und EN erhalten identische Aufgabenstruktur. Tooltips ergänzen Details, ersetzen keine primäre Beschriftung.

## E. Technische Architektur des späteren Umbaus

### E.1 Verantwortlichkeiten und Dateien

| Dateien | Verantwortung nach Umbau | Konkrete Grenze |
|---|---|---|
| `UX.lua`, `UXCreate.lua`, `UXLayout.lua`, `UXViews.lua` | bestehende Primitiven und Hülle, Seitenregistrierung, Refresh/Navigation als kompatible Fassaden | `U.Navigate`, `U.Page`, `Set*View`, `Open*` bleiben für bisherige Aufrufer erreichbar; numerische IDs nicht global blind ersetzen |
| **neu:** `UXNavigation.lua` | kanonische Routen, Alt-Aliase, validierter RAM-Rückkehrkontext | keine Netzwerk-/Fachobjektkopien und keine dauerhaften privaten Formulardaten |
| **optional später:** `UXComponents.lua` | nur aus P3 und späterem zweiten Verbraucher nachgewiesen gemeinsame Layoutteile | Nicht in P1 anlegen. Bestehende/lokale Helper zuerst; Extraktion braucht benannte Verbraucher, klare Grenze und passende Regression, kein Framework auf Vorrat |
| `UIState.lua` | erlaubte neue UI-Routen plus gezielte Normalisierung alter UI-Navigation | Geschäfts-SavedVariables unverändert; ungültige gespeicherte Loginroute sicher normalisieren, interaktive unbekannte Deep Links nach E.3.1 ohne Navigation abfangen; nicht Rootdaten neu initialisieren |
| `ResponsiveUI.lua` | gemeinsames Größenmodell statt weiterer Seitenheuristiken | migrierte Bereiche besitzen Layout selbst; Legacybereiche bis zur Ablösung weiter kompatibel |
| `Theme.lua`, `ThemeCommunity.lua`, `Locale.lua` | vorhandene Themeverträge/Übersetzungen; Community-spezifische Tokens ergänzen | Theme.lua ist gemeinsame Kopie laut Header; Änderungen nur wenn nötig an bestehender Quelle `_dev/shared/Theme.lua` planen und Synchronisation gesondert beachten. Community-Primitiven bevorzugt in ThemeCommunity/UXComponents |
| `AccountOverviewUI.lua`, `UXPageProfile.lua` | erste vollständige Layoutreferenz: Charakterblatt und gespeicherte Gegenstandssuche, öffentliche Bearbeitung vom Privatblatt getrennt | `AccountOverview.lua`, `Main.SetMain/RemoveCharacter` und Importregeln unverändert konsumieren |
| `CommunityHomeUI.lua`, `UXSessions.lua` | drei Dashboardprojektionen, kompakte Wünsche mit vorhandenem Editor | keine zweite Match-/Zeit-/Publikationslogik |
| `ActivityDetailsUI.lua`, `ActivityArchiveUI.lua`, `UXPageGroups.lua`, `UXGroups.lua`, `ScheduledGroupsUI.lua`, `FormLayoutUI.lua`, `SchedulePickersUI.lua`, `PvPHelpUI.lua` | gemeinsame Aktivitätspräsentation, bestehende Formulare/Typaktionen | `ActivityBoard`, `ScheduledGroups`, `GroupFinder`, `QuestHelper`, `PvPHelp`, `ActivityParty` behalten Zustände und Autorität |
| `UXPageQuests.lua`, `UXQuests.lua` | drei verständliche Questansichten; Hilfe-/Spielerdetail | QuestGroups/QuestHelper unverändert; keine Zusammenlegung gemeinsamer Quests und Bewerbungen |
| `UXPageMembers.lua`, `UXMembers.lua`, `UXMemberGroups.lua`, `SocialDiaryUI.lua`, `CategorySettingsUI.lua` | progressive Filter, Kontaktblatt, Main/Alt-Ziele | private Schlüsselsemantik, Social/SocialCategories/SocialDiary/History bleiben erhalten |
| `UXPageCraft.lua`, `UXCrafting.lua`, `ProfessionHistoryUI.lua` | Rezept-Handwerker-Anfrage-Materialfluss und Auftragsliste | ProfessionScan/RecipeSearch/CraftOrders/MaterialPlanner bleiben Daten-/State-Autoritäten |
| `UXPageTrade.lua`, `UXTrade.lua` | drei Arbeitsansichten und Angebotsaktion, kontextbezogenes Angebot | TradeManager bleibt Gültigkeits-/Vorlagen-/Regelbesitzer |
| **neu:** `UXSettings.lua`; `UXPageProfile.lua`, `CommunityHomeUI.lua` | direkte Settingsgruppen statt Buttonstartseite | keine neuen fachlichen Präferenzen oder neuen Schalter für interne Werte; nur tatsächlich angebotene Controls, bestehende Setter und Scope unverändert |
| `UXAddons.lua`, `UXPageProfile.lua`, `CompanionUI.lua`, `NetworkSetup.lua`, `NotificationInboxUI.lua`, `UXNotices.lua`, `NoticeUI.lua`, `UI.lua` | Zusatzflächen in dieselbe Interaktionssprache einbinden | Provider-, Focus-, Combat-, Read-Marker- und Exportverträge erhalten |
| `ZenialCommunity.toc` | neue reine UI-Module an deterministischer Position laden | Fachmodule davor, Konstruktion erst nachdem alle UI-Funktionen verfügbar sind; Theme vor UI; kein Callback auf noch nicht geladenen Besitzer |

`UXNavigation.lua` ist die kleine P1-Grenze; `UXSettings.lua` entsteht erst mit P2. `UXComponents.lua` ist optional nach abgenommener Charakterreferenz und tatsächlichem Wiederverwendungsbedarf, keine verbindlich dritte neue Datei. AccountOverview/Netzwerk/Core werden nicht umstrukturiert. Falls sich eine vorgeschlagene Primitivenfunktion mit einem bestehenden Helper deckt, bestehenden Helper erweitern statt duplizieren.

### E.2 Vorgeschlagene Schnittstellen für getrennte Worker

Die folgenden Navigationsnamen sind **vorgeschlagene UI-Verträge**, nicht heute bestehende APIs. P1 implementiert nur die benötigte Auflösung, Legacy-Fassaden, Eingabe-/Rückkehrabsicherung. Die Darstellung der alten Ansichten bleibt zunächst erhalten; neue Ansichten werden phasenweise registriert, Aliase dürfen bis dahin auf den korrekten alten Besitzer zeigen. Kein vorgezogener Umbau aller Fachseiten. Vor Umsetzung muss die Freigabe nach P0 vorliegen.

```text
Route = {section, view?, selection?}
  section: today | activities | quests | members | craft | trade | characters | settings
  view: erlaubter Schlüssel aus der Routentabelle in P1
  selection: {kind?, owner?, id?, characterKey?, peerKey?}; nur Strings

U.Navigate(section, subview?, selection?) -> nil       # bestehende Fassade erhalten
U.Navigation.Resolve(section, subview?, selection?) -> Route? route, string? reason
U.Navigation.Open(route, {returnToken?}?) -> boolean success, string? reason
U.Navigation.BeginContext(kind, payload, returnRoute) -> string token
U.Navigation.Return(token) -> boolean success, string? reason
U.Navigation.DiscardContext(token) -> nil

```

Routenschlüssel: activities=`discover|mine|planned`, quests=`shared|help|questgroups`, craft=`search|orders|mine`, trade=`browse|mine|rules`, characters=`overview|items|public`, settings=`display|privacy|connection|notifications|integrations|advanced`; today und members ohne Pflicht-Unteransicht. Alias `craft/materials` wird `craft/orders` plus Einkaufslistenfilter, `trade/manage` wird `trade/mine` plus Zustandsfilter. Filterzustand und Scrollposition werden von der jeweiligen Ansicht gehalten; nicht als neue Navigationsebene modellieren.

Bestehende `selection` bei `U.Navigate('addons', ..., index)` und charakter-/peerbezogene Open-Aufrufe brauchen ausdrücklich einen Adapter zum alten Parametertyp. Ein generischer Selectiontable-Vertrag darf die bisherigen optionalen Parameter nicht brechen. Zahlen/Strings aus alten Aufrufern werden pro Alias geprüft, nicht pauschal akzeptiert.

`BeginContext('craft', payload, returnRoute)` besitzt diese verbindliche Payload-Allowlist: `peerKey` (echter Handwerkerkey), `recipeRef` (bestehendes validiertes Rezeptobjekt nur lesend referenziert), `quantityText` (gewünschte Stückzahl), `craftsText` (separate Craftvorgänge), `tipGoldText` (unveränderter Eingabetext einschließlich Komma/Punkt), `noteText`, `materialsProvided` (Boolean), optionale `planID` und `materialItemID` sowie ursprüngliche Filter-/Seiten-/Scroll-/Selektionswerte des UI-Kontexts. Größen-/Zeichengrenzen sind dieselben wie an den bestehenden Eingabefeldern; Texte werden nicht durch vorzeitige Zahlenkonvertierung verändert. Die `returnRoute` ist die vorhandene Route vor dem Arbeitsausflug. Kein Fachobjekt wird serialisiert oder in einen neuen Datenstore kopiert.

IDs und Eingaben bleiben im RAM, begrenzt auf höchstens einen aktiven Herstellungskontext; Modal schließen während eines expliziten Ausflugs verwirft ihn nicht. Explizites Abbrechen, Logout/Reload oder erfolgreiche Übergabe beendet ihn. Rückkehr prüft Kontakt, Rezept, Plan und Fachzustand neu; sie stellt auch noch ungültige Eingabetexte unverändert dar und benutzt anschließend dieselbe bestehende Formularvalidierung beim Senden. Verschwundene Quellen erklären statt stale Aktion ausführen. Stückzahl und Craftzahl werden niemals gleichgesetzt. Verbindlicher P1/P7-Roundtriptest: **7 Stück, 3 Crafts, Trinkgeldtext `1,25`, individuelle Notiz und Materialien gestellt=true** über Liste→Handelsangebot→Zurück exakt erhalten; einmaliger bewusster Versand rechnet Trinkgeld wie bisher in Copper um.

### E.3 Routenkompatibilität und Migration

- `groups/today`→Heute; `groups/browse`→Aktivitäten/Entdecken; `groups/mine/outgoing/follow/scheduled/pvp`→passende Ansicht/Filter bzw. PvP-Detail. Keine Umdeutung einer ausgewählten fremden Aktivität in eigene Aktivität.
- `quests/shared/questgroups` bleiben; `browse/mine/outgoing`→Questhilfe mit passendem Filter. Fach-Unread-Ziele in `Notifications` bleiben gültig und werden erst an der UI-Grenze aufgelöst.
- `profile/characters` und `OpenAccountOverview/OpenMyCharacters`→Meine Charaktere/Übersicht; `profile/public`→Öffentliches Profil des aktuellen Chars; `display/network`→Settings. `history` öffnet dieselbe Zeitlinie mit Rückkehrquelle. `addons` öffnet denselben Manager unter Integrationen.
- `UIState.Initialize` darf bestehende `root.ui.characters` gezielt normalisieren; alte Profile-/Angebotsentwürfe, Fensterwerte und Benachrichtigungen behalten. Keine neue Persistenz von group/quest/scheduled-Eingaben: `UIState.Draft:58` verwirft diese bewusst, `ActivityInput:64` ist RAM.
- Keine Migration von account overview, AccountPreferences, Kontakten, PrivateNotes, TradeStore oder Netzwerkversionen. Ein UI-Versionswechsel ist nur nötig, wenn sich tatsächlich gespeicherte Navigationswerte ändern; idempotent, verlustfrei, unbekannte neuere Geschäftsdatenschemata weiter read-only.
- Neue Quellmodule in TOC aufnehmen; UI-Ladereihenfolge per Test fixieren. `docs/UX-REDESIGN-PLAN.md` bleibt lokales Planungsartefakt und gehört nicht ins Addon-ZIP. Das vorhandene Workspace-Lint verbietet Markdown in Runtimeordnern: der Nutzer wünscht hier ausdrücklich diesen Pfad. Kein pauschales Aufweichen des Lints; bei späterem Packaging das Dokument außerhalb des Runtime-Manifests halten.

### E.3.1 Deep Links: vor dem Wechsel vollständig prüfen

**B – aktueller Stand:** `UXLayout.Navigate:186` fällt bei unbekannter Section auf Heute zurück und ruft sofort `Page` auf; `Page:216` schließt auch beim gleichen Seitenziel Dialoge. `CloseDialogs:522–572` sichert private Notizdrafts, versteckt aber weitere Formulare und löscht u. a. `craftOrderContext`. `ActivityDetailsUI.OpenActivity:84` prüft einen fehlenden Boardkey bereits vor dem Schließen und meldet ihn korrekt; bei gültigem Ziel setzt es jedoch Detailnotiz/Rolle zurück. `UXNotices.OpenUpdate:281` setzt Selektionen/Read-Marker früh und fällt bei fehlendem Event auf Legacy-scheduled zurück. `OpenApplications:170` kann auf eine aktuelle eigene Aktivität ausweichen. Diese Pfade sind nicht als bereits eingabesicher ausgegeben.

**E – verbindlicher P1-Vertrag:**

1. Bekannten Legacy-Alias und zulässige Parameter ohne UI-Mutation auflösen. Routenfehler (`unknown-section`, `unknown-view`, `invalid-selection`) und nicht mehr vorhandene oder nicht zugängliche Ziele (`target-unavailable`) geben `nil/false` plus verständlichen Grund zurück. Eine valide gespeicherte Loginpräferenz kann weiterhin normalisiert werden; ein fehlgeschlagener interaktiver Link darf nicht still nach Heute wechseln.
2. Vollständige Objektidentität prüfen: bei Aktivität **kind + owner + id**, bei Kontakt/Charakter exakt der scoped key, bei Angebot Owner + Offer-ID. Falsche Art, Besitzer, Revision, blockierter Peer oder entfernte Quelle erlauben keine Auswahl des ersten/aktuellen/gleichnamigen Datensatzes. Ein gültiger alter Alias darf dieselbe Funktion am neuen Ort öffnen; ein ungültiges altes Ziel bleibt ungültig.
3. Ziel und Quelle müssen vor `Page`, `CloseDialogs`, Selektion, Formularreset und fachlichem Read-Marker geprüft werden. Bei Fehler bleibt der Ursprung samt offenen Werten, bestehendem Rückkehrtoken, Scroll und Auswahl erhalten; Statusmeldung: „Dieses Ziel ist nicht mehr verfügbar“ bzw. „Dieser Verweis wird nicht unterstützt“. Kein Dummyobjekt und kein automatisches Verwerfen/Publizieren.
4. Auch ein **gültiger** Link darf laufende Eingaben nicht still löschen. Bestehende RAM-/Draftpfade (`ActivityInput`, Angebots-/Profilentwurf, Notizdraft, begrenzter Herstellungskontext) nutzen, soweit der konkrete Dialog sie wiederherstellt. Fehlt ein sicherer vorhandener Rückkehrpfad, Navigation ohne Schließen abbrechen: „Ungespeicherte Bearbeitung zuerst speichern oder ausdrücklich abbrechen; danach den Verweis erneut öffnen“. Kein neuer globaler Draftstore und keine automatische Persistenz von Aktivitätsformularen. Absichtliches Neuöffnen/Verwerfen nach bisherigem Editorvertrag bleibt eine bewusste eigene Aktion.
5. Erst nach erfolgreicher Auflösung und Eingabeprüfung Route/Auswahl gemeinsam übernehmen; unmittelbar vor einer Fachaktion Ziel/Revision erneut prüfen. Verschwindet es nach der Navigation, Detail auf „nicht mehr verfügbar“ und Aktionen aus; nicht auf Nachbarobjekt springen. Öffnen desselben Ziels ist ohne ausdrücklichen Neustart kein Formularreset. `Notifications.ReadRecent` beim Glockenöffnen bleibt von fachlichen Read-Tokens getrennt.

**Pflichttests:** unbekannte Section/Subview, entfernter Live-/Quest-/Termin-/Handelsdatensatz, gleiche ID bei anderem Besitzer oder anderer Art, geblockter Peer, nicht mehr vorhandener Charakter, P1-Auflösung während offener Craft-/Group-/Quest-/Termin-/Angebots-/Profil-/Notizbearbeitung; Null Änderungen an Quellwerten/Selektion/Token bei Abbruch. Benachrichtigungslink darf keine andere eigene Aktivität öffnen. Ein gültiger Link plus sichere Rückkehr bewahrt Eingaben, ein gültiger Link ohne sichere Wiederherstellung bleibt bis Speichern/Abbrechen am Ursprung. Client-Fokus/ESC/Combat zusätzlich nach G.4. Bestehende Tests liefern Teilbelege, diese vollständige Matrix ist noch zu ergänzen.

### E.4 Einheitliche Responsive-Strategie

**E – vorläufiger, in P0 zu prüfender Größenrahmen:** Bei Standard-Scale 1 Größen 900×610, 1060×690 und 1280×860 weiter unterstützen. P0 erfasst logische Fenstergröße, tatsächlich gerenderte Größe, UIParent/UI-Scale und Benutzer-Scale getrennt. Erst gemessene Clientbelege bestätigen oder korrigieren die folgenden Inhalts-Breakpoints; keine neue Bildschirmkompatibilität vorab behaupten. Hauptfenstergrenzen und gespeicherter User-Scale bleiben zunächst erhalten. Inhaltsanpassung ersetzt automatisches Verkleinern der gesamten Seite.

- **Breit:** tatsächliche Inhaltsbreite mindestens 860 (P0-05-Nutzerentscheid 2026-11-10 nach Web-Simulation, vorher angenommen 800; Begründung: bei 1060×690 mit Inhalt 848 kürzte die 280er-Liste alle Untertitel und das Detail hatte nur eine Metrikspalte); Liste mindestens 280, Detail mindestens 420, Lücke 16. Flexible Restbreite; Listen und Detail scrollen bei Bedarf unabhängig, Kopf/Primäraktion bleiben fest.
- **Schmal:** unter 860 Inhaltsbreite (damit auch Standard 1060×690) gemeinsame Einspaltenansicht; erst Liste, Auswahl öffnet Detail mit „Zurück zu Ergebnissen“. Charakterblatt/Spielerprofil bekommen die ganze verfügbare Inhaltsbreite. Kein abgeschnittenes Restpanel. Schwelle auf Inhaltsbreite nach Sidebar/Insets anwenden, nicht nur auf Fensterbreite.
- **Höhe:** normale Kopf-/Filtergruppen insgesamt Ziel ≤120; Rest für Inhalt. Zusätzliche Filter werden umgebrochen oder in Erweitert gelegt. Kein erzwungener Mindestlistenbereich größer als der verfügbare Bereich. Metrikabschnitte bei wenig Höhe untereinander in einem Detail-Scroll.
- **Schrift/Scale:** Seite nicht mehr nach Höhe proportional skalieren; Benutzer-Scale respektieren. Größere Schrift benötigt Reflow und weniger gleichzeitige Inhalte, keinen Rückfall auf winzige Schrift. Auf sehr kleinen Screens reale sichtbare Höhe inklusive Frame-Scale prüfen; Dialoge an verfügbare Bildschirmfläche begrenzen.
- **Modals:** maximale nutzbare Bildschirmbreite/-höhe mit Rändern, fester Titel/Footer und nur Formularbody scrollbar; keine Sidebar-überdeckenden Vollflächen. Bei externem Join/native Chat Fokusvertrag erhalten.
- **DE/EN:** Textbreite messen und umbrechen; Buttons mindestens 28 hoch, bei Wrap 36–40; Gefahr-/Primäraktionen nicht durch Ellipse unkenntlich. Tools erklären ergänzende Informationen, keine versteckten Hauptfunktionen im Compactmodus.
- **Performance:** Größe und Datenrevision getrennt invalidieren; Footer-Reflow bei Resize gebündelt, Widgets einmal erzeugen, sichtbare Zeilen recyceln. Ein eintreffendes Netzpaket ändert das betroffene Modell/Detail, baut nicht die gesamte Anwendung neu auf.

### E.5 Risiko- und Reviewfokus

1. Aktiver Twink wechselt während Auswahl: eindeutiges sichtbares Aktionsziel, private Markierungen bleiben am bisherigen Schlüssel (P4).
2. Eigener/fremder Termin ändert Revision/Status oder endet während offener Details: Autorität neu prüfen, keine stale Bestätigung/Einladung (P5a/P5b).
3. Legacy-/unbekanntes Accountschema, andere Fraktion/Realm, Utility-only und gelöschte Quelle: keine unzulässige Mutation, keine stillen Imports (P3).
4. Rückkehr aus Handelsdetail nach verschwundenem Rezept/Handwerker oder `/reload`: verständlicher Zustand, keine fremde Herstellungsanfrage (P7/P8).
5. Modal/ESC/native Chat bei Kampfwechsel und Netzrefresh: keine verschluckten Bewegungs-/Chatkeys, kein automatischer geschützter Aufruf (P1/P9).

## F. Ausführbarer Umbauplan nach ausdrücklicher Freigabe

**Alle 13 Pakete P0, P1–P4, P5a–P5c und P6–P10 sind noch offen.** P0 wird in diesem reinen Planungsdurchlauf weder ausgeführt noch als bestanden markiert. Abnahme und Beginn einer weiteren Produktphase setzen jeweils die passenden Regressionen und den dokumentierten visuellen Clientcheck G.4 voraus. Die erledigten Analysepunkte oben sind keine umgesetzten Redesignphasen. Jeder Worker erhält diesen Plan, den fixierten/neuen Basis-HEAD, sein Dateipaket, unveränderte Domainverträge, Testfälle und Nichtziele. Worker committen nicht selbst; Integration erfolgt nach Diffabnahme durch den Orchestrator und den dann geltenden Gitregeln. In diesem Durchlauf weiterhin keine Commits.

**Testharness-Abhängigkeit:** Die vorhandenen Tests liegen im eigenständigen übergeordneten Repository `wow/_dev/tests`, nicht im Community-Repository. Sie werden aus `wow/` mit Lua 5.1/Lupa ausgeführt und laden `ZenialCommunity/`. Die unten ausdrücklich genannten Testdateien sind der geplante Test-Schreibbereich einer später genehmigten Umsetzung. Vor Teständerungen dort eigenen Branch/isolierten Arbeitsstand sichern; die vorhandenen Nutzeränderungen im wow-Repository dürfen weder übernommen noch committet werden. Community-Änderungen und Harnessänderungen müssen im Abnahmeprotokoll mit ihren jeweiligen Repository-/Branchständen aufgeführt werden. Kein stilles Anlegen von Tests in verteilten Runtime-ZIPs.

**Arbeitszyklus je Produktphase:** nach freigegebenem P0-Ergebnis erst den benannten Verhaltensfall im Harness absichern, erwartetes Altverhalten/Fehler vor UIänderung dokumentieren, kleinste UIänderung implementieren, passende Tests ausführen, tatsächlichen Diff prüfen und **vor Phasenabschluss die visuelle Forever-Abnahme G.4 ausführen**, Status/letzten Check/nächsten Einstieg im Plan aktualisieren. Ohne Clientbeleg bleibt die Phase „Clientabnahme ausstehend“, auch wenn Harnessprüfungen bestehen. Keine reinen Pixel-Implementierungsspiegeltests; UI-Geometrie zusätzlich visuell im Client prüfen. Die folgenden Checkboxen bleiben bis zur späteren Umsetzung leer.

### P0 – Visuelle Bestandsaufnahme und frühe Client-Machbarkeit

**Ziel:** die statischen Aussagen und Größenannahmen am aktuellen unveränderten WoW-Forever-Build mit echten Fontmetriken, Frames, Fokus und Combat abgleichen, bevor produktives Layout umgebaut wird. **Nur geplant, aktuell nicht ausgeführt.**

**Schreibgrenze nach ausdrücklicher P0-Ausführungsfreigabe:** QA-Belege im bestehenden `wow/_dev/addons/ZenialCommunity/` und dieser Plan; Produkt-Lua bleibt in P0 unverändert. Die kleine wegwerfbare Layoutprobe läuft getrennt in einer lokalen Testumgebung/Test-Addoninstanz mit statischen Beispieldaten; sie wird nicht in TOC, Runtimeexport, Produkt-SavedVariables oder Releases übernommen. Kein Featureprototyp, kein Versand, kein Invite, keine Datenmigration.

- [x] **P0-01 Umgebung erfassen:** *(erledigt 2026-11-10, P0-QA §6)* Produkt-/Clientbuild, Addon-HEAD/TOC, Locale DE/EN, Monitorauflösung, UIParent-Breite/-Höhe, globale WoW-UI-Scale, gespeicherter Benutzer-Scale (`Z.db.scale`) und logische/gerenderte Fenstermaße dokumentieren. Separate Testprofile mit gesicherten Daten verwenden; kein neuer Benutzer-Scale-Regler im Produkt.
- [x] **P0-02 konkrete Ist-Screenshots:** *(erledigt 2026-11-10: 16 Produktansichten deDE bei 1279×858; 1060×690 über proportionale Seitenskalierung ableitbar (P0-WEB-ERGEBNIS.md); enUS, Addon-Manager 0/6 Provider und Kompaktzustände nach Auswahl bleiben offen)* `Heute`, `Aktivitäten-Liste+Vorschau`, `Aktivitätsdetail-fremd`, `Aktivitätsdetail-eigen-mit-Teilnehmern`, `Terminliste+Editor`, `Quests-shared+Questgruppen`, `Mitspieler-Main+aktiver-Twink`, `Handwerk-Rezept+Anfragemodal+Materialliste`, `Handelsuche+Editor`, `Meine-Charaktere+gemischte-Itemsuche`, `Settings+Verbindung`, `Addon-Manager-0/1/6-Provider-soweit-verfügbar`, `Companion`, `Diary`, `Inbox` sowie größtes Archiv-/Bestätigungs-/Kalender-/Kategoriedialog exemplarisch aufnehmen. Nicht verfügbare reale Providerzustände als offen kennzeichnen, nicht als visuell geprüft ausgeben. Hauptansichten in beiden Sprachen bei 1060×690/Scale 1; problematische Ansichten zusätzlich in der Matrix unten.
- [x] **P0-03 Mindestgröße/Scale-Matrix:** *(erledigt 2026-11-10 als kalibrierte Web-Simulation (120 Zustände), Fit gegen gemessene UIParent 2133×1200)* logische Mindestgröße **900×610** mit Benutzer-Scale **0,65 / 1 / 1,4**; Standard **1060×690** und groß **1280×860** mit Scale 1. Zusätzlich **1280×860 bei 1,4** als Bildschirm-Fit-/Negativfall. Je Zustand DE/EN und Sidebar mit optionalem Manager sichtbar/ausgeblendet prüfen. Ausgangsmonitor 1920×1080; reale UIParent-Maße und tatsächliche Darstellung entscheiden. Bei 1280×860×1,4 passt die Höhe ggf. nicht auf diesen Bildschirm: Clipping als Befund erfassen, keine bestandene Unterstützung behaupten; Fit-Fall bei verfügbarer 2560×1440-Konfiguration ergänzen. Falls UIParent-/Monitorfläche die Mindestkombination nicht trägt, unterstützte Grenze vor P1 fachlich festlegen, statt Schrift unter die Benutzerwahl zu skalieren.
- [x] **P0-04 kleine Layoutprobe:** *(erledigt 2026-11-10: Client-Probe 900/1060/1280 + Web-Port; Clientmessung bei 1280×860 bestätigt die Simulation)* nur Charakterlayout A mit echter bestehender Hülle/Sidebar und vorhandenen `S.label/button/list`-/Theme-Helpers nachstellen: links drei statische Charakterzeilen inkl. langem Namen, rechts Kopf, zwei Metrikabschnitte und Taschen-/Bank-Erfassungsstatus, eine vorhandene-artige Mehraktion und ein begrenztes Beispielmodal. Keine neue Komponentenbibliothek. Breite Ansicht bei 1060×690 und 1280×860, Einspalten-/Zurückvariante bei 900×610 vergleichen; Screens `Probe-A-breit`, `Probe-A-schmal`, `Probe-A-Modal`, `Probe-A-DE-EN-lang` aus der Matrix erfassen. Auswahl/Zieltext/Scroll nur lokal simulieren; keine vollständige Charakterfunktion bauen.
- [x] **P0-05 Machbarkeitsentscheid:** *(gemessen, Breakpoint 860 entschieden, Client-ESC/Chat/Kampf bestanden mit Befund P0-B5; Größen-/Layoutrahmen vom Nutzer am 2026-11-10 freigegeben)* sichtbare Text-/Aktionsbreiten, minimale Detailfläche, geeigneten Umschaltpunkt, Inhaltshöhe mit Joinbanner, Sidebarhöhe mit optionalem Manager und Modal-Footer messen. Den zunächst angenommenen 800-Inhaltspixel-Breakpoint aus E.4 bestätigen oder begründet ändern. **Teilentscheid 2026-11-10:** auf 860 geändert (Web-Simulation, P0-WEB-ERGEBNIS.md); Client-Gegenprobe bleibt offen. ESC/Fokus, native Chatfokussierung und Kampfwechsel mit bestehendem Code/G.4 beobachten; keine zusätzlichen geschützten Probeaktionen erfinden.

**Ablage und Belegnamen:** je Zustand `<Phase>/<Locale>/<logische-Größe>-scale<Benutzerwert>-manager<an|aus>-<Ansicht>.png` im genannten QA-Bereich; Begleitdatensatz mit realen Maßen, UI-Scale, HEAD, Datum und Pass/Fail. Persönliche Namen/Inhalte für teilbare Belege anonymisieren. Fehlender Clientzugang oder nicht vorhandener Testzustand bleibt ausdrücklich offen; Mockbilder ersetzen diesen Nachweis nicht.

**Regression/Prüfkriterien:** unverändertes Produkt-HEAD/Lua, unveränderte Testprofil-Fachwerte durch reine Layoutprobe; Pflichtaktionen/Schrift/Sidebar bleiben sichtbar, keine blockierten Bewegungs-/Chatkeys, keine Lua-/Protected-Aktionsfehler aus der Probe. Abweichungen des Bestands sind Auditbefunde und nicht von P0 schon behoben.

**Abhängigkeit:** ausdrückliche Freigabe zur P0-Ausführung und zugänglicher echter Forever-Client. **Risiko:** Layoutprobe verfälscht Ergebnisse durch andere Scale-/Font-/Framehierarchie; deshalb echte Helpers und getrennte Messwerte. **DoD:** Ist-Belege + begrenzte Probe + Größen-/Breakpointentscheid mit offenen Befunden liegen vor; User gibt den bestätigten Layout-/Größenrahmen vor Produktumsetzung frei. P0 ist kein Auftrag, in diesem Dokumentationsdurchlauf Client oder Code zu verändern.

### P1 – Minimale Navigation, Legacy-Aliase und Rücksprungschutz

**Ziel:** bestehende Routen sicher auflösen und laufende Arbeit erhalten; keine neue UI-Bibliothek und kein Komplettumbau der Seitendarstellung.

**Dateien:** `UXLayout.lua`, `UXViews.lua`, `UIState.lua`, `UXNotices.lua` und Open-Einstiege nur soweit für Vorprüfung/Rückkehr erforderlich, optional kleine neue `UXNavigation.lua` + TOC-Eintrag. Keine `UXComponents.lua`, keine neue `SplitView/FilterBar/ActionBar`, keine globalen Theme-/Responsive-Umbauten in P1. Tests im wow-Harness: `test_community_navigation_clicks.lua`, `test_notifications.lua`, `test_community_compact.lua`, `test_community_review42_state.lua`, `test_material_planner_network_ui.lua` sowie konkrete Deep-Linkfälle nach E.3.1.

- [ ] Alte Aliase/Parameter und exakte Fachobjektidentitäten erfassen. Aktuelle alte Frames dürfen bis zum jeweiligen Seitenumbau die Routenziele bleiben. `characters/overview` kann zunächst auf den bestehenden Profil-Charakterframe zeigen; keine vollständige neue Hauptnavigation als Voraussetzung für P3.
- [ ] E.3.1 vor `Page/CloseDialogs` umsetzen: unbekannte/veraltete Ziele ohne Navigation oder Ersatzselektion erklären; gültiges Ziel mit offener ungesicherter Bearbeitung schützt Eingaben durch vorhandene Wiederherstellung oder bleibt am Ursprung. Login-Normalisierung ist kein Deep-Link-Fallback.
- [ ] Begrenzten RAM-Rückkehrvertrag aus E.2 mit getrennten Formulartexten/echtem Ziel definieren; Modal-Schließen, Arbeitsausflug und ausdrückliches Verwerfen auseinanderhalten. Noch keine neue Herstellungs-/Handelsoberfläche; P7/P8 verbinden ihre späteren Ansichten mit diesem Vertrag.
- [ ] Harness: unbekannte Route/Subview, fehlende oder gleichlautende falsche Art/Owner/ID, entfernter Charakter/blocked Peer, offene Angebots-/Profil-/Aktivitäts-/Craft-/Notizfelder; bei Fehler unveränderte Eingaben, Auswahl, Scroll, Read-Token und Kontext. Roundtripwerte 7 Stück/3 Crafts/1,25 Gold bleiben getrennt, keine Fachaktion durch Routing.

**Abhängigkeit:** P0-Ergebnisse und Freigabe. **Risiko:** hoch an bestehenden OnHide-/Draft-/Notificationpfaden trotz engem Umfang. **DoD:** Alias-/Fehler-/Eingabematrix bestanden, Fachwerte durch Routing unverändert, alte Open-APIs erreichbar; sichtbare alte Oberfläche bleibt funktionsfähig. Visuelle Clientabnahme G.4 auf unverändertem Bestand und den korrigierten Einstiegen ist Pflicht. Kein Abschluss nur mit Harness, keine Primitiven auf Vorrat.

### P3 – Meine Charaktere und klar getrenntes öffentliches Profil (höchste Seitenpriorität)

**Ziel:** gewähltes Charakterlayout A aus C.7 als erste vollständig umgesetzte und visuell abgenommene Layoutreferenz; klar abgegrenzte gespeicherte Gegenstandssuche und Datenherkunft.

**Dateien:** `AccountOverviewUI.lua`, `UXPageProfile.lua`, bestehende Helpers in `UX.lua`/`ThemeCommunity.lua` nur bei konkretem Bedarf, `Locale.lua`. Keine vorab benötigte UXComponents-/UXSettings-Bibliothek; Aufnahmeoptionen bleiben zunächst im vorhandenen Kontext. `AccountOverview.lua`, `AccountPreferences.lua`, `Main.SetMain/RemoveCharacter` ausschließlich als unveränderte Abhängigkeiten. Tests: `test_account_overview.lua`, `test_community_profile_layout.lua`, `test_community_own_profile.lua`, `test_companion_account.lua`.

- [ ] Bestehende Filter-/Auswahlmodelle in Charakterblatt überführen; Gold/Erholung/Spielzeit/Berufe/Taschen/Bank als typisierte Abschnitte statt Auswahltextzeilen darstellen.
- [ ] Charakter- und Itemsuche trennen; „Gespeicherte Gegenstände“ verwendet ausschließlich `AccountOverview.Search` mit bestehenden Mindestlängen/Limits/Holdern und Scopefiltern. Kein ungefilterter Inhaltsbrowser, kein Slotraster, kein neuer Lagerort-/Einzelcharakterfilter; Snapshotzeit und Importquelle aus vorhandenen Daten zeigen.
- [ ] Bestehende Main-/Hide-/Delete-/Import-Aktionen und sämtliche Guards erhalten; lokales Aufnahmeopt-in separat von öffentlichem Profil und Companion erklären.
- [ ] Tests: Realm A/B und Fraktion A/B, aktueller/Utility-only/ausgeblendeter/normaler Char, read-only neues Schema, mehrdeutiger Utilityimport, fehlende Bank/Itemnamen, aktualisierte Bags bei alter Bank; öffentliches Profil enthält kein einziges privates Overviewfeld.

**Abhängigkeit:** P0/P1; vor P2 und allen weiteren vollständigen Fachlayouts. Lokale einfache Helper/Anker aus dem konkreten Blatt entwickeln; erst ein zweiter passender Verbraucher rechtfertigt spätere Extraktion. **Risiko:** hoch wegen Identität/Löschfolgen/Datenschutz, geringe gewünschte Domainänderung = null. **DoD:** alle bestehenden Aktionen und Einschränkungen unverändert; Name-/Itemsuche unabhängige Ergebnisse; alle Informationsblöcke bei Mindestgröße erreichbar; keine neue SavedVariables-Migration. Alternative B wird nicht zusätzlich gebaut.

**Verpflichtende Phasenabnahme:** nach den genannten Regressionen G.4 am tatsächlichen Forever-Client durchführen und dokumentieren: DE/EN, Mindestgröße und Benutzer-Scales, Sidebar mit Manager an/aus, betroffene Modale/ESC/Fokus/Combat; ohne Belege keine Abnahme und kein Beginn der abhängigen Produktphase.


### P2 – Hauptnavigation und ausschließlich bereits angebotene Einstellungen

**Ziel:** Acht verständliche Einstiege, Charaktere direkt erreichbar, Settings mit vorhandenen Optionen.

**Dateien:** neu `UXSettings.lua`; ändern `UXCreate.lua`, `UXLayout.lua`, `UX.lua`, `UXPageProfile.lua`, `CommunityHomeUI.lua`, `UIState.lua`, `Locale.lua`, `ZenialCommunity.toc`. Tests: `test_community_navigation_clicks.lua`, `test_community_connection_profile.lua`, `test_community_profile_layout.lua`, `test_community_review42_state.lua`.

- [ ] Acht Hauptrouten und Defaults aus B einrichten; öffentliche/private Profileinstiege umleiten, optionalen Manager-Shortcut mit bestehendem Default/Verfügbarkeitsprüfung erhalten.
- [ ] Settingskategorien nur mit tatsächlich angebotenen Controls aus A.4 befüllen; visible/shareProfessions und vorhandene Aufnahme-/Integrations-/Fensteraktionen übernehmen. consent/autoDiscovery/shareGuild/shareQuests bleiben interne Gates ohne neue Schalter; bestehende Karten-/Slashbedienung nicht zu neuen Settingsreglern erweitern.
- [ ] Profil-Darstellung/Verbindungs-Tabs als Alt-Aliase erhalten; Hilfe-/Diagnose-/Joinwege rückkehrfähig machen; keine leeren Allgemein-Kategorien anlegen.
- [ ] Tests: gleiche Preferences vor/nach Darstellung und Reload; Toggle ruft bisherigen Setter mit identischem Wert auf; Manager-Option false bleibt false, keine vorhandenen Freigaben ändern sich beim Upgrade.

**Abhängigkeit:** P1 und abgenommene Charakterreferenz P3. Bestehende Helpers und nur bereits bewährte Teile der Referenz verwenden; keine zweite umfassende Layoutarchitektur. **Risiko:** mittel-hoch, weil `UIState.Initialize` alte Routen schon umdeutet. **DoD:** alle acht Seiten über sichtbares Menü, höchstens eine Unterebene, keine Funktionslücke aus B.4; gespeicherte Werte außer bewusst normalisiertem UIrouting identisch. Keine neue Profilbearbeitung fremder Offlinecharaktere.

**Verpflichtende Phasenabnahme:** nach den genannten Regressionen G.4 am tatsächlichen Forever-Client durchführen und dokumentieren: DE/EN, Mindestgröße und Benutzer-Scales, Sidebar mit Manager an/aus, betroffene Modale/ESC/Fokus/Combat; ohne Belege keine Abnahme und kein Beginn der abhängigen Produktphase.


### P4 – Mitspieler und private Kontakte

**Ziel:** Suche und schnelle Kontaktaktion vorn, erweiterte Filter und privater Kontext verständlich.

**Dateien:** `UXPageMembers.lua`, `UXMembers.lua`, `UXMemberGroups.lua` nur erforderliche Präsentation, `CategorySettingsUI.lua`, `SocialDiaryUI.lua`, `CommunityHomeUI.lua` nur bisherige Member-Umbauten herauslösen, `Locale.lua`. Tests: `test_community_member_groups.lua`, `test_community_member_grouped_list.lua`, `test_community_member_group_actions.lua`, `test_social_categories.lua`, `test_social_categories_network.lua`, `test_social_diary.lua`, `test_community_review42_ui.lua`.

- [ ] Schnellfilter Suche/Online/Favoriten/Gilde, übrige Filter in Erweitert; Mainheader, aktiver Twink und Einzelcharakterauswahl eindeutig darstellen.
- [ ] Kontaktblatt mit öffentlichem Inhalt und privater Notiz/Kategorie trennen, Aktionsziel am Button benennen; reale Schlüssel-/FollowActive-Semantik erhalten.
- [ ] Kategorienverwaltung aus Kontaktkontext öffnen, alte Popup-API aliasen; Social Diary und Kontakthistorie als zwei benannte Bestände mit ihren bestehenden Filtern/Aufnahmeoptionen zugänglich halten.
- [ ] Tests: aktiver Twink wechselt während Gruppenheaderauswahl; Einzelchar bleibt exakt; widersprüchliche Mainclaims/Zyklen/fehlender Main/falscher Scope/blocked; Note-Draft bleibt beim richtigen key; Diary-Forget löscht weder Favorit noch Notiz, Kategorienlöschung nur ihre Zuordnungen.

**Abhängigkeit:** P1/P2, abgestimmte Identitätsdarstellung P3; keine gemeinsame Dateibearbeitung parallel zu P3. **Risiko:** hoch bei Aktions-/Notizziel, Cache-/Refreshlast. **DoD:** Main erkennbar, Einladen/Flüstern korrekt, alle Filter erreichbar, kein neuer öffentlicher Privatdatenexport, große Listen weiter revisioniert/virtualisiert; kompakter Rückweg erhält Zustand.

**Verpflichtende Phasenabnahme:** nach den genannten Regressionen G.4 am tatsächlichen Forever-Client durchführen und dokumentieren: DE/EN, Mindestgröße und Benutzer-Scales, Sidebar mit Manager an/aus, betroffene Modale/ESC/Fokus/Combat; ohne Belege keine Abnahme und kein Beginn der abhängigen Produktphase.


### P5a – Aktivitätenliste und typisierte Details

**Ziel:** Entdecken mit Auswahl und direkt verfügbaren erlaubten Aktionen; vorhandene Detail-/Fachlogik wiederverwenden, bevor persönliche Verwaltung und Composer folgen.

**Dateien:** Board-/Detailteile von `CommunityHomeUI.lua`, `ActivityDetailsUI.lua`, `UXGroups.lua`, erforderliche Routingadapter und `Locale.lua`. Vorhandene OWN-/Termin-/PvP-Aktionen bleiben während des Teilumbaus erreichbar; ihre Oberfläche wird erst in P5b/P5c weiter konsolidiert. Tests: `test_community_activity_actions.lua`, `test_community_navigation_clicks.lua`, `test_community_compact.lua`, `test_notifications.lua`.

- [ ] Entdecken-Liste mit bestehender Zeit-/Typ-/Suchfilterung und Pagination aufbauen; Zeilenauswahl zeigt Detail ohne zusätzlichen Öffnen-Klick. Herkunft LIVE/QUEST/EVENT/PVP klar vom Aktivitätskategoriefilter trennen.
- [ ] Eine effektive `OpenActivity`-Fassade und ein tatsächliches Detailmodell; existierende Apply-/Withdraw-/Whisper-/Diaryaktionen mit typabhängigen Guards beibehalten. Eigentümeraktionen nicht vor P5b entfernen.
- [ ] Breite/kompakte Aufteilung aus der abgenommenen Charakterreferenz anpassen. Erst bei tatsächlich passender wiederholter Logik gemeinsamen Helper extrahieren; kein globales Komponentenpaket nachholen.
- [ ] Regression: Owner/foreign/saved/offline/blocked, Daten verschwinden zwischen Auswahl und Aktion, gleiche ID anderer Art/Owner, pending/abgelaufen, fehlende Gruppengröße = unbekannt, Rückweg/Pagination/Filter und gehaltene Klicks bei Refresh. Stale Detail darf keine andere Aktivität annehmen/einladen.

**Abhängigkeit:** P1/P3/P2; P4 liefert geprüfte Kontaktziele. **Risiko:** hoch bei Typ-/Auswahl-/Handlerkonsolidierung. **DoD:** Entdecken zeigt erlaubte Aktionen direkt, ein effektiver Detaileinstieg, unveränderte Fachguards/Netzwerk-Tickreihenfolge, kein verlorener OWN-/Legacyweg. G.4 visuell: fremde/eigene Detailvarianten, lange Titel, leer/expired, schmale Rückkehr, Modal/ESC/Fokus/Combat in DE/EN; Ergebnisse dokumentiert.

### P5b – Eigene Aktivitäten, Bewerbungen und Termine

**Ziel:** vollständiger persönlicher Bestand und Geplant-Ansicht mit denselben gültigen Aktionen; vorhandener Composer bleibt bis P5c nutzbar.

**Dateien:** persönliche Filter/Boardteile `CommunityHomeUI.lua`, eigene Detailteile `ActivityDetailsUI.lua`, `UXGroups.lua`, `UXPageGroups.lua`, `ScheduledGroupsUI.lua`, `ActivityArchiveUI.lua`, gezielte Zeit-/Serienformularstellen `FormLayoutUI.lua`/`SchedulePickersUI.lua`, `UXNotices.lua`, `Locale.lua`. Tests: `test_community_activity_actions.lua`, `test_community_scheduled_details.lua`, `test_scheduled_groups.lua`, `test_scheduled_groups_network_ui.lua`, `test_community_activity_archive.lua`, `test_community_activity_recreate.lua`.

- [ ] Meine Aktivitäten mit Organisiert-/Bewerbungsfiltern, gespeicherten Offline-/Legacyzuständen und Geplant mit Besitz-/Teilnahmefilter; keine fachlichen Daten aus dem alten Bestand verlieren.
- [ ] Bewerber/Teilnehmer, Bestätigen/Warteliste/Ablehnen/Einladen nach Art übernehmen: Live-/Questannehmen lädt ein; Terminbestätigen ändert Teilnahme und ist keine Einladung. Einzel-/Sammelinvite und native Fehler/dedupe behalten.
- [ ] Archivieren/Absagen/Erneut erstellen sowie Wiederholen→Vorschau→Instanzen erreichbar machen. Vorhandene Datums-/Uhrzeitfehler verständlich anzeigen und den bestehenden Modus weiterverwenden; keine neue sichtbare UTC-Auswahl ohne separate fachliche Prüfung, keine neue Zeit-/Serienlogik.
- [ ] Regression: stale Event-/Teilnehmerrevision, Ownerrecht fehlt, volle Rollen-/Gruppenkapazität, pending, Start/Ende/Absage während Auswahl, Saved-Applikation ohne Owner, entfernte Archivquelle, Wiedererstellen ohne alte ID/Teilnehmer, DST-Lücke/Doppelstunde/LOCAL-UTC, Serienvorschau nach Änderung ungültig.

**Abhängigkeit:** P5a. **Risiko:** hoch bei persönlichen Zuständen, Absage-/Archivfolgen und Revisionen. **DoD:** jeder bisherige eigene/beworbene/terminierte Bestand und seine Fachaktion erreichbar, kein Ersatzobjekt bei altem Link, erlaubte Folgeaktion direkt am Objekt; bestehendes Erstellen/Bearbeiten weiterhin möglich. G.4 visuell: lange Teilnehmerliste, leere persönliche Liste, Archiv-/Serienbestätigung, Datum/Uhrzeit/Konvertierungsfehler, Manager-Sidebar, ESC/Fokus/Combat in DE/EN; eigene Belege pro Teilphase.

### P5c – Composer, PvP und vereinfachtes Heute

**Ziel:** vorhandene Erstellung/PvP-Workflows konsistent halten und Heute auf die drei entschiedenen Inhalte reduzieren.

**Dateien:** Home-/Creator-/Wunschteile `CommunityHomeUI.lua`, `UXSessions.lua`, `FormLayoutUI.lua`, `SchedulePickersUI.lua`, `UXGroups.lua`, `UXPageGroups.lua`, `PvPHelpUI.lua`, nötige Archive-/Notice-Adapter und `Locale.lua`. Tests: `test_community_activity_recreate.lua`, `test_community_activity_actions.lua`, `test_scheduled_groups_network_ui.lua`, `test_session_plans.lua`, `test_session_plans_network_ui.lua`, `test_pvp_help_layout.lua` sowie vorhandene PvP-Domain-/UI-Suiten aus dem Harness.

- [ ] Composer mit bestehenden Typ-/Zeitwahl- und Detailformularen, Vorlagenbenutzung/-löschung unabhängig vom Gruppenleerzustand und explizitem Speichern/Veröffentlichen. Bestehende Formular-/Draft-/Verwerfenregeln behalten, Deep Links nach E.3.1 schützen laufende Eingaben.
- [ ] PvP-Kopfweg, eigener Ruf/Bereitschaft, Vorschau, Pflichtangriffsbestätigung, optionale Gegnerfreigabe, Helfer-/Karten-/Wegpunktaktionen mit unveränderten Voraussetzungen und Adapterrechten konsolidieren.
- [ ] Heute exakt offene eigene Aufgaben, jetzt relevante Aktivitäten und nächste Termine darstellen. Wünsche standardmäßig kompakt mit Bearbeiten im bestehenden begrenzten Dialog; kein Pflichtinlineformular, keine zusätzliche große Mitspielerkarte oder neue Aufgaben-Domain.
- [ ] Regression Composer: Live/Quest/Event, eine aktive Anfrage/Gruppe, Auto-/manuelle Rollenbedarfe, Vorlage, Editobjekt verschwunden, Zurück/Verwerfen/Reload, keine Publikation beim Anzeigen.
- [ ] Regression PvP: PvPflag, zwei Tode, Todesort/Cooldown, Ghost, Angriff nicht bestätigt, Gegnerfreigabe, coming/withdrawn, offline/voll/kein Einladerecht, Chatfokus; Testmodus bleibt Diagnosefall.
- [ ] Regression Heute/Wünsche: keine Wünsche/keine Treffer/keine Aufgaben/keine Termine, vorhandene Match-/Zeit-/Teilnahmezustände, maximal drei Wünsche, Revision schützt offene Bearbeitung, Speichern/Löschen privat, kurze Heute-Aktionswege bleiben. Keine dauerhaft offenen Eingabefelder nach Laden/Resize.

**Abhängigkeit:** P5a/P5b und geprüfte Kontakt-/Rückkehrverträge. **Risiko:** hoch an Formwrappern/OnHide/Combat. **DoD:** Composer-, PvP- und Dashboardkriterien jeweils einzeln bestanden; keine Fachfunktion/Bestätigung entfernt, keine neue Automatisierung. G.4 visuell: Composer mit langen DE-/EN-Labels, Wunschdialog offen/geschlossen, drei ruhige Homebereiche, PvP-Vorschau/Helper und Calendarpopup bei Mindestgröße/Scales; ESC/Tab/native Chat/Kampfwechsel geprüft. P5c bleibt offen, wenn einer dieser drei Nachweise fehlt.

### P6 – Quests als zusammenhängende Zusammenarbeit

**Ziel:** Meine Quests / Questhilfe / Questgruppen, passende Spieler direkt an der Quest.

**Dateien:** `UXPageQuests.lua`, `UXQuests.lua`, `UXNotices.lua`, `CommunityHomeUI.lua` nur erforderliche Querverweise, `Locale.lua`. QuestHelper/QuestGroups unverändert. Tests: `test_quest_helper_default_view.lua`, `test_quest_helper_categories.lua`, `test_quest_helper_ui.lua`, `test_quest_helper_scan.lua`, `test_quest_helper_timing.lua`, `test_quest_helper_network.lua`.

- [ ] Shared als verständlichen Standard „Meine Quests“ benennen, realen Questlog-/Sharingstand direkt erläutern; Kategorieeinklappung und Suchzustand erhalten.
- [ ] Explizite Hilfe mit Filter Alle/Meine Anfragen/Meine Hilfsangebote zusammenführen; alte browse/mine/outgoing-Ziele auf denselben Datensatz/Filter abbilden.
- [ ] Passende Spieler und gültige Zeilenaktionen, lokale Questgruppenvorschläge und Coverage/Intersection verständlich darstellen. Ein aktiver Hilfe-Request bleibt die Grenze.
- [ ] Tests: eigener Questscan fehlt/alt/Combat deferred; hidden/blocked/offline Peer; Quest nicht mehr im Log vor Invite; eigener aktiver Request öffnet Bearbeiten statt Duplikat; Vorschlag bleibt Vorschlag, kein neuer Gruppenmitgliedschaftszustand.

**Abhängigkeit:** P1, P4, P5a-Questdetailadapter und P5c-Composer. **Risiko:** mittel-hoch. **DoD:** alle fünf alten Questansichten fachlich enthalten, Shared-Standard bei Eintritt/Reload erhalten, Hilfe und gleichzeitiger Questbesitz klar verschieden; keine neue Questnetzwerklogik.

**Verpflichtende Phasenabnahme:** nach den genannten Regressionen G.4 am tatsächlichen Forever-Client durchführen und dokumentieren: DE/EN, Mindestgröße und Benutzer-Scales, Sidebar mit Manager an/aus, betroffene Modale/ESC/Fokus/Combat; ohne Belege keine Abnahme und kein Beginn der abhängigen Produktphase.


### P7 – Handwerk und Materialfluss

**Ziel:** Rezept → Handwerker → Materialprüfung → Anfrage bleibt ein zusammenhängender Vorgang.

**Dateien:** `UXPageCraft.lua`, `UXCrafting.lua`, `UXViews.lua`, `FormLayoutUI.lua`, `ProfessionHistoryUI.lua`, `UXNavigation.lua` nur Vertragsergänzung nach zentraler Abnahme, `Locale.lua`. Tests: `test_material_planner.lua`, `test_material_planner_network_ui.lua`, `test_community_review_ui.lua` sowie vorhandene passende Profession-/Recipe-/Craftorders-Suiten nach G.3.

- [ ] Rezept-/Berufstreffer und gewählten Handwerker im gemeinsamen Detail halten; Remote-Suchstart/Abbruch und Scan-/Katalogstatus unverändert konsumieren.
- [ ] Anfrageabschnitte für Stückzahl, Craftvorgänge, Trinkgeld, Materialzusage, Nachricht; optional Materialliste und Angebote im Kontext; Aufträge-Filter einschließlich Einkaufslisten.
- [ ] P1-RAM-Kontext bei Handelsausflug befüllen; erfolgreiche Rückkehr revalidiert, explizites Abbrechen verwirft, erfolgreiche Anfrage/Teilerfolg erklärt Ergebnis. Keine Speicherung dieses Kontexts in öffentlichen Feldern oder SavedVariables.
- [ ] Tests: Handwerker offline/cap30 fehlt/Rezept entlernt, Suchantwort veraltet, Teilscan/fehlende Materialien/unbekannte Ausbeute, älteste Liste reserviert zuerst, Auftrag terminal/weg; Anfrage→Liste→Angebot→Zurück erhält alle Eingaben und erlaubt exakt dieselbe Anfrage.

**Abhängigkeit:** P1/P5c-Formgrundlage, P8 konsumiert Rückkehrvertrag. **Risiko:** hoch, Auftragszustände und Einkauf sind verschiedene Dinge. **DoD:** voller Ablauf mit gleichem peer/recipe/plan möglich; Menge nicht mit Craftanzahl gleichgesetzt, manuelles Materialmarkieren löst keine Auftragsbestätigung aus; alle bisherigen Auftragsübergänge bedienbar.

**Verpflichtende Phasenabnahme:** nach den genannten Regressionen G.4 am tatsächlichen Forever-Client durchführen und dokumentieren: DE/EN, Mindestgröße und Benutzer-Scales, Sidebar mit Manager an/aus, betroffene Modale/ESC/Fokus/Combat; ohne Belege keine Abnahme und kein Beginn der abhängigen Produktphase.


### P8 – Handel mit drei Arbeitsansichten

**Ziel:** Finden / Meine Angebote / Suchalarme; Angebot erstellen ist eine Aktion.

**Dateien:** `UXPageTrade.lua`, `UXTrade.lua`, `UXViews.lua`, `FormLayoutUI.lua`, `UXNotices.lua`, `Locale.lua`. Tests: `test_trade_item_selection.lua`, `test_material_planner_network_ui.lua`, `test_notifications.lua`, vorhandene TradeManager-Suiten.

- [ ] Vier Altansichten auf drei Sollansichten abbilden, Erstellen/Editieren als Arbeitsdialog; aktive/entworfene/pausierte/abgelaufene/abgeschlossene/Vorlagenzustände über klare Filter.
- [ ] Preis/Kategorie/Sortierung unter Erweitert, aktive Filter sichtbar; gespeicherte Suche als vorhandenen Suchalarm beschriften, keine neue Regelart.
- [ ] Suchalarmtreffer mit vorhandener Offer-ID öffnen, fehlenden/geschlossenen Treffer mit Snapshotstatus erklären; bestehende Unreadregeln respektieren. Materialoffer setzt Rückkehrtoken statt Anfrage zu verwerfen.
- [ ] Tests: Price copper int, Gold/Silber/Kupfer, exakte Item-ID/lokalisierter Name, Ablauf während Editor, Quelle beim Publish konsumiert aber Vorlage erhalten, Pause/Complete mit Retract, keine Alarme für Loginbaseline, aktualisierter/geschlossener Treffer; P7-End-to-End erneut einmal ausführen.

**Abhängigkeit:** P1/P7-Kontextvertrag; gemeinsame Dateien P7/P8 sequenziell. **Risiko:** mittel-hoch. **DoD:** jeder bisherige Angebotszustand/Aktion erreichbar, nichts automatisch republiziert, Entwürfe und Vorlagen unverändert nutzbar, Materialrückweg geprüft.

**Verpflichtende Phasenabnahme:** nach den genannten Regressionen G.4 am tatsächlichen Forever-Client durchführen und dokumentieren: DE/EN, Mindestgröße und Benutzer-Scales, Sidebar mit Manager an/aus, betroffene Modale/ESC/Fokus/Combat; ohne Belege keine Abnahme und kein Beginn der abhängigen Produktphase.


### P9 – Addon Manager, Companion und alle Zusatzdialoge

**Ziel:** ruhige Integrationsübersicht und einheitliche Kontext-/Fehlerrückmeldungen, ohne Integrationssemantik zu verändern.

**Dateien:** `UXAddons.lua`, `UXPageProfile.lua` verbliebener Managerbuilder, `UXSettings.lua`, `CompanionUI.lua`, `NetworkSetup.lua`, `UI.lua`, `NotificationInboxUI.lua`, `UXNotices.lua`, `NoticeUI.lua`, `Locale.lua`; Launcher/Provider/Companionexport nur unveränderte Abhängigkeiten. Tests: `test_community_connection_profile.lua`, `test_community_discovery_ui.lua`, `test_notifications.lua`, `test_companion_onboarding.lua`, vorhandene Addonpanel-/Launcher-Suiten nach G.3.

- [ ] Vertikale Addonliste und Status-/Version-/Beschreibungsbereich, ein gecachter Providerhost, alle Zustände und externe Fallbacks; Shortcutoption erhalten.
- [ ] Companionstatus leicht verständlich, Exportumfang neben Aktivierung, Technikdetail optional; bestehender SetExportEnabled schaltet Kategorien wie bisher, keine behaupteten neuen Einzelfreigaben.
- [ ] Join-/Kopier-/Kalender-/Diagnose-/Backup-/Kategorie-/Archiv-/Diary-/Inbox-Flächen auf Titel, Footer, Fokus/ESC/Rückkehr und Größenregeln prüfen; verbliebene Sonderdialoge erhalten expliziten Layoutbesitzer.
- [ ] Tests: fehlendes/deaktiviertes/nicht ladbares/noch ladendes/legacy/ready Addon, Providerfehler/Refreshfehler, sechs lange Versionen, Nullprovider; Recent gelesen vs Fachtoken ungelesen, veraltetes Ziel, Beta-/Combat-Join, keine automatischen Fokus-/Clipboard-/Gameaktionen.

**Abhängigkeit:** P1/P3/P2, P4, P5a–P5c sowie fertige Fachziele P6–P8. **Risiko:** hoch an externen Frames/Fokus, gering für gewünschte Geschäftsänderung = null. **DoD:** jedes in A.2/A.3 genannte Fenster hat erhaltene Fähigkeit und Rückkehr, Addonpanelverträge identisch, keine private Accountveröffentlichung und keine neue Companionfunktion.

**Verpflichtende Phasenabnahme:** nach den genannten Regressionen G.4 am tatsächlichen Forever-Client durchführen und dokumentieren: DE/EN, Mindestgröße und Benutzer-Scales, Sidebar mit Manager an/aus, betroffene Modale/ESC/Fokus/Combat; ohne Belege keine Abnahme und kein Beginn der abhängigen Produktphase.


### P10 – Responsive, Regression und Freigabe zur Veröffentlichung

**Ziel:** Gesamtsystem lesbar und funktionsgleich abnehmen; keine Veröffentlichung in dieser Phase automatisch auslösen.

**Dateien:** gezielte Layoutkorrekturen in `ResponsiveUI.lua`, `UXComponents.lua`, `ThemeCommunity.lua`, den betroffenen Seiten, `Locale.lua`; Test-/QA-Berichte im bestehenden `_dev/addons/ZenialCommunity/` des wow-Workspace. Keine pauschale Theme-/Fachmodulbereinigung.

- [ ] Gesamte Matrix G und Journeys J bei 900×610, 1060×690, 1280×860, DE/EN, User-Scale 0,65/1/1,4 sowie realen Bildschirmen prüfen. Join-Banner, Modale und Dropdowns mit einbeziehen.
- [ ] Netzwerkänderungen bei offener Eingabe/Selektion, 1000 Kontakte, 100 Materiallisten, Maximalzustände und wiederholte Resizevorgänge messen; keinen Frame-/Request-/Refreshwachstum pro Paket zulassen.
- [ ] Funktionszuordnung B.4 gegen echten Build abhaken, Source-/SavedVariables-/Netzwerk-/Privacyvergleich durchführen; verbleibende Legacyhandler nur entfernen, wenn kein Aufrufer und keine Fähigkeit mehr daran hängt.
- [ ] Ingamebelege, Harnessergebnisse und tatsächliche Klickwege mit Build-HEAD dokumentieren; offene Mängel priorisieren. Separater Review der Release-Dateiliste schließt docs/Tests/Analyseartefakte aus.

**Abhängigkeit:** abgenommenes P0 und alle Produktpakete P1/P3/P2/P4/P5a/P5b/P5c/P6/P7/P8/P9 einschließlich ihrer jeweiligen G.4-Belege. **Risiko:** mittel-hoch bei kombinierten Größen/Fokus/Events. **DoD:** keine verlorene Funktion, alle kritischen Regressionen bestanden, Pflichtaktionen vollständig erreichbar und lesbar, kein unbeabsichtigter Schutzaktionsfehler; native Clientbelege vorhanden. Push/Merge/Release/Deployment benötigen die dann erforderliche ausdrückliche Freigabe.

**Verpflichtende Phasenabnahme:** nach den genannten Regressionen G.4 am tatsächlichen Forever-Client durchführen und dokumentieren: DE/EN, Mindestgröße und Benutzer-Scales, Sidebar mit Manager an/aus, betroffene Modale/ESC/Fokus/Combat; ohne Belege keine Abnahme und kein Beginn der abhängigen Produktphase.


### F.1 Abhängigkeiten und sichere Delegation

```text
P0 (Client-Ist + Layoutprobe + Größenfreigabe)
 → P1 (nur Navigation/Aliase/Rückkehr)
 → P3 (erste vollständige Charakterlayout-A-Referenz + Clientabnahme)
 → P2 → P4 → P5a → P5b → P5c → P6 → P7 → P8 → P9 → P10
```

Die IDs bleiben erhalten, die Reihenfolge setzt bewusst **P3 vor P2**. P6 konsumiert Questdetail aus P5a und den vorhandenen/konsolidierten Composer aus P5c; P7 braucht die Form-/Rückkehrgrenzen, P8 den P7-Einkaufskontext. P10 ist Zusammenführungs-/Gesamtabnahme, nicht der erste visuelle Test.

Schreibarbeit konservativ sequenziell, weil UXViews/FormLayout/Home/Locale gemeinsame Dateien sind. Insbesondere P5a/P5b/P5c, P5c/P6 und P7/P8 nicht gleichzeitig in denselben Dateien bearbeiten. Nur nach expliziter Dateitrennung parallelisieren; unabhängige Nur-Lese-Prüfungen bleiben möglich. Orchestrator besitzt Routenkontrakt, bestehende Fachgrenzen und Abnahme; Worker starten keine weiteren Worker. Neue Primitiven nur mit benannten tatsächlichen Verbrauchern aus P3 und mindestens einer späteren Ansicht, nicht als Abschlusskriterium einer Grundlagenphase. Jeder Worker meldet geänderte Dateien, passende Harnesschecks **und** G.4-Clientbelege bzw. den Status „Clientabnahme ausstehend“.

## G. Regressions- und Testplan

### G.1 Verhaltensmatrix

| Bereich / verantwortliche Phase | Konkrete Fälle und erwartetes Ergebnis | Nachweismethode |
|---|---|---|
| Navigation / P1–P2 | jeder alte Abschnitt/Subview/Deep Link, Slashalias, Benachrichtigungsziel; identischer kind/owner/id, eigener/fremder gleichnamiger Datensatz; unbekanntes Ziel erklärt statt falscher Aktion | Harness über echte Open-/Click-Handler; E.3.1-Fehler-/Dirtymatrix ergänzen und Aliasmatrix B.4 abhaken |
| Rückweg / P1/P7/P8 | Liste→Detail→Zurück erhält Filter, Seite, Scroll, Selektion; Herstellung→Liste→Handel→Zurück erhält alle Eingaben; Abbrechen/Reload verwirft nur RAM-Arbeitskontext | Handler-End-to-End; Vorher-/Nachherzustand vergleichen |
| Fenster / P0 und jede Produktphase nach G.4 | 900×610, 1060×690, 1280×860; hohe/schmale Zwischenformate, Joinbanner an/aus; User-Scale 0,65/1/1,4 + verschiedene UIParent-Skalen | Geometrieassertions für Pflichtflächen + Ingame-Screenshots, keine Überlappung/unerreichbare Pflichtaktion |
| Charakterdaten / P3 | 0/1/viele Charaktere; aktuell, Main, Twink, anderer Realm, andere Fraktion, Utility-only; kein Snapshot/Teilwerte/alt; jede Feldzeit separat | AccountOverview-Harness; UIzustände aus realen Models, Snapshotvergleich |
| Main/Twink / P3/P4 | Main setzen nur gleicher Scope; aktueller nicht lösch-/ausblendbar; Löschen bisherigen Mains setzt erlaubten Fallback; widersprüchliche/zyklische Claims; aktiver Twink wechselt | bestehende Scope-/Gruppierungssuiten; echter APIzielname bei Invite/Whisper prüfen |
| Private Kontakte / P4 | Notizentwurf bei Auswahlwechsel; private Kategorien umbenennen/löschen/max20/neueres Schema; Diary opt-in/Quellen/Retentionsgrenzen, Forget erhält Notiz/Favorit | Social-/Category-/Diary-Suiten; neue UIhandler gegen denselben Store |
| Gruppen/Bewerbungen / P5a/P5b | applied/invited/rejected/withdrawn/joined/expired, fehlender Owner, Eigentümer-/Einladerecht, voll, offline, Gruppenwechsel während Detail | Status und Fachbackendaufruf prüfen; keine Statusänderung nach fehlgeschlagenem nativen Invite |
| Termine / P5b | OPEN/DRAFT/CANCELLED/FINISHED; vor/nach Start/Ende; pending/revision stale, Rollenplätze voll, Warteliste; alle bestätigten einladen nur erlaubt, 30-s-Dedupe | Scheduled-/Activity-Suiten; Änderung während offener Auswahl simulieren |
| Zeit/Serie / P5b | gültige lokale Zeit, DST-Lücke/doppelte Stunde, LOCAL/UTC-Roundtrip, 1–4 Serieninstanzen, Vorschau invalidiert nach Eingabeänderung, Horizont/Kapazität | ScheduleTime/ScheduledGroups; Preview vor Veröffentlichung zwingend, keine still korrigierte Zeit |
| Quests / P6 | shared als Default, Hilfe nicht gleich Questbesitz; Scan alt/unbekannt/Combat deferred; Quest vor Klick aufgegeben; explizite Anfrage manuell/ID0; eine aktive Anfrage; lokale Vorschlagscoverage | Questhelper-/Group-Harness; tatsächlicher Query/Inviteaufruf, keine künstliche Mitgliedschaft |
| PvP / P5c/P9 | nicht PvP, ein/zwei Tode, Todesort fehlt, Cooldown, Ghost/lebt, Angriff nicht bestätigt, Gegnerdatenfreigabe an/aus, coming/withdrawn, Helfer offline/voll | PvP-Harness plus tatsächlicher Forever-Client; bisherige CanCall-/InvitePvp-Regeln unverändert |
| Herstellung / P7 | fremd/eigen/offline/cap30 fehlt, Rezept bekannt/entlernt, Queryantwort alt, Teil-/Vollscan; Mengen/Trinkgeld/Notizgrenzen; requested→accepted→ready→completed und Decline/Cancel/Expire | Craftorders-/Recipe-/Profession-Suiten; Berechtigung beider Seiten, erwartete Revision; Besteller bestätigt Handoff |
| Materialien / P7 | Ausbeute unbekannt, Materialien unvollständig, Bestand unbekannt/0, mehrere reservierende Listen, max100, älteste aktive zuerst, terminaler/fehlender Auftrag | MaterialPlanner-Suiten; eigene Bank nicht als live vorhandener Bestand verwenden; manuelle Haken lösen keine Übergabe aus |
| Handel / P8 | SELL/BUY/SERVICE, Text vs exakte Item-ID, Stück-/Gesamtpreis, Ganzzahl Copper, Ablauf/Retraction während Auswahl/Editor, private Drafts/Vorlagen/Pause/Complete/Duplicate/Relist | TradeManager-/Itemselection-Suiten; keine automatische Publikation; Quelle vs Vorlage korrekt konsumiert |
| Alarme/Inbox / P8/P9 | Loginbaseline still, neue/geänderte/geschlossene Angebote, blockierter Peer, Ziel verschwunden, Recent gelesen/fachlich ungelesen, Callback nach Reload fehlt | Notifications-Suite; rückkehrfähiger Deep Link oder expliziter Status, kein Phantomdatensatz |
| SavedVariables / P1/P3/P10 | alter UIzustand, unbekannte neuere Teilversion, beschädigte UIroute, bestehende Drafts/History/Account/Pairing | normalisierten Snapshot vor/nach vergleichen; nur dokumentierte UI-Normalisierung, keine Fachdatenlöschung |
| Datenschutz / P2/P3/P9 | angebotene visible/shareProfessions-Controls bedienen; consent/autoDiscovery/shareGuild/shareQuests nur als bestehende Backend-/Fixturezustände prüfen (keine neuen UI-Schalter), alte Jobs/offlineOnly/blocked/Realm-/Fraktionsscope; Preview öffentlich vs lokale Daten | Netzwerk-Payloads/Queue prüfen; vorhandene CancelPublic-/PrivacyChanged-Aufrufe erhalten; keine Accountgold-/Bank-/Privatnotizfelder im öffentlichen Profil |
| Companion / P9 | Export aus/an, bestehende categories, SetExportEnabled-all-data, private Topic, aktive Inventar-/Charakterdaten, Questflächen/Combatpause, minimiert/veraltet | Companion-Suiten + Client/Empfänger; Datenumfang weder erweitern noch als Communityprofil missverstehen |
| Addon Manager / P9 | missing/disabled/unavailable/loading/reload/ready/legacy, API!=1, CreatePanel-Fehler, fehlender Refresh, 0/1/6 Provider | kontrollierte Provider-Mocks + installierte Clientversionen; einmaliges CreatePanel, Hide beim Wechsel/Schließen, externer Slashfallback unverändert |
| Sprache/Leerzustände / P0 und jede Produktphase | DE/EN, sehr lange Namen/Realm/Überschriften/Notizen, 0/1/25/26 Einträge, ausgefilterte vs nicht erhaltene vs gesperrte Daten | identische Journeys, Textumbruch/Labels/Zeitzone prüfen; Filter-Reset nur vorhandene Filterwerte |
| Netzwerkupdates / P1/P5a–P5c/P10 sowie je betroffene Phase | Updates während Hover/Mousedown/Formulareingabe/Selektion/Resize; 1000 Peers, wiederholter Snapshot, ablaufende Datensätze | bestehende Releaseclick- und Snapshot-Tests, Frameanzahl/Requestzähler und Timings; keine weggeblendete Maustaste und kein kompletter Neuaufbau |
| Forever/Combat / P0 und jede Produktphase nach G.4 | Combat startet/endet bei offenem Modal, native Chat-/Joinfokussierung, fehlende optionale API/Template/Atlas, protected calls | reale Clientsitzung mit Fehlererfassung; bestehende Adapter-Fallbacks behalten. A.Invite hat heute keinen expliziten Combatguard: keine neue Sperre als bereits bestehend behaupten |

### G.2 Messbare Qualitätsziele und Akzeptanz

- Jede Standardhauptseite aus geöffneter Anwendung mit **einem Hauptmenüklick** erreichbar; eigene Charakterübersicht nicht hinter Settings.
- Breites Aktivitätenboard: Auswahl zeigt Inhalt und erlaubte Hauptaktionen, **kein zusätzlicher Öffnen-Klick**. Bereits kurze Heute-Aktionen nicht verlängern.
- Kein regulärer Workflow benötigt mehr als **eine Untermenüebene**; Filter und Formularschritte verständlich als solche beschriftet.
- Ab ausgewähltem Mitspieler höchstens eine bewusste Kontaktaktion; Aktionsziel und gespeicherter Notizempfänger jederzeit erkennbar. Ab ausgewählter Quest gültigen Mitspieler direkt einladen können.
- Herstellungsworkflow verliert bei Material-/Handelsausflug **keinen** noch gültigen Eingabewert und bindet ihn an dasselbe Rezept/Peer/Plan. Keine automatische Neuverknüpfung nach Datenverlust.
- Bei Mindestgröße/DE/EN sind **100 % der Pflichtaktionen** ohne abgeschnittene Beschriftung und mit eindeutigem Rückweg erreichbar; Scrollen ist erlaubt, unsichtbare Bedienflächen nicht.
- Bei wiederholtem identischem Snapshot werden keine neuen Domainrequests erzeugt; Framepool nach Aufwärmen stabil. Bei Netzwerkburst nur betroffene sichtbare Daten aktualisieren. Quantitative CPU-/Speicherbudgets nach gemessener Basis festlegen, keine erfundenen Millisekundenzusagen.
- Datenschutz-/Domainregressionen: **null unbeabsichtigte Feld-/Payload-/Berechtigungs-/SavedVariablesänderungen** außerhalb ausdrücklich genehmigter UIroute-Normalisierung.
- Nach P10 fünf neue oder wenig erfahrene Spieler dieselben Kernaufgaben testen lassen: Ziel ≥4/5 finden Hauptbereich und Primäraktion ohne Hilfe. Dies ist ein geplanter Nutzertest, aktuell nicht durchgeführt und keine behauptete statistische Wirksamkeit.

### G.3 Prüfwerkzeuge und Grenzen

Vorhanden ist `wow/_dev/tools/check.py` mit `lupa.lua51`, TOC-/Packagingprüfung und vielen Addonsuiten. **Nicht blind in diesem Planungsdurchlauf ausführen:** es umfasst fremde Addons und verbietet jede Markdown-Datei im Runtimeordner; die explizit gewünschte lokale docs-Datei würde daher einen bekannten Dokumentablagebefund auslösen. Das ist keine Lua-Regression und kein Anlass, Regeln oder Source zu ändern.

Gezielte bestehende Tests aus `wow/` laufen ohne Repositoryskriptänderung so (Beispiel, Pfad/Interpreter vorhanden prüfen):

```powershell
@'
from pathlib import Path
from lupa.lua51 import LuaRuntime
names = ['test_account_overview.lua', 'test_community_member_group_actions.lua',
         'test_quest_helper_default_view.lua', 'test_social_diary.lua',
         'test_social_categories.lua']
for name in names:
    path = Path('_dev/tests') / name
    LuaRuntime(unpack_returned_tuples=True).execute(
        path.read_text(encoding='utf-8-sig'), name='@' + path.as_posix())
    print('PASS', name)
'@ | & .\_dev\.venv\Scripts\python.exe -
```

Weitere existierende Fachtests vor jeder Umsetzung mit `rg --files _dev/tests` auffinden; tatsächliche Namen für Recipe/Profession/Craft/Trade/Addonprovider in den Workerbrief aufnehmen, statt hier einen nicht vorhandenen Testnamen zu erfinden. Tests aus eigenständigem Community-Checkout brauchen das vorhandene Harness samt Mock und korrekte Ordnerzuordnung als externe Testabhängigkeit. Keine Bibliotheken/Mocks während dieses Analysedurchlaufs installieren.

Harness beweist Handler-/Zustandsverhalten, nicht native APIverfügbarkeit, reale Schriftmetriken, Strata, Combat-Schutz oder erreichbare Communitykommunikation. Für diese Punkte sind Forever-Client, zwei Testspieler für Netzwerk-/Bewerbungsfälle und dokumentierte Ingamebelege erforderlich. Dieser Plan wurde nicht im Spiel visuell ausgeführt.

### G.4 Verpflichtende visuelle Clientabnahme nach jeder Produktphase

Diese Schranke gilt einzeln für **P1, P3, P2, P4, P5a, P5b, P5c, P6, P7, P8 und P9** sowie nochmals zusammenführend für P10; P0 ermittelt zuvor die reale Baseline und bestätigten Grenzen. Harness-PASS oder ein später vorgesehenes P10 ersetzt keinen Phasennachweis. Ohne echten Clientzugang lautet der Status „Clientabnahme ausstehend“ und die abhängige Produktphase beginnt nicht.

| Check-ID | Pflichtzustand je Phase | Nachweis / bestanden wenn |
|---|---|---|
| V01 Sprache und Mindestfenster | betroffene Ansicht in **deDE und enUS**, logische **900×610**, Benutzer-Scale **0,65 / 1 / 1,4**, reale UIParent-/WoW-UI-Scale dokumentiert | Namen, Labels, Primär-/Gefahraktionen, Detail-/Zurückweg ohne Clipping/Überdeckung; Schrift respektiert Benutzerwahl |
| V02 Sidebar/Manager | jeden V01-Zustand mit optionalem Addon-Manager-Hauptshortcut **an und aus**; Providerverfügbarkeit notieren | gesamte Hauptnavigation inkl. Charaktere/Settings und optionalem Shortcut erreichbar; keine Kollision unten/mit Footer, kein versehentlich anderer aktiver Punkt |
| V03 Standard/groß | **1060×690** und **1280×860** bei Scale 1, je DE/EN; zusätzlich seit P0 bekannte problematische Screen-/Scalefälle | korrektes Umschalten zwischen konkreter Listen-/Detailvariante und schmaler Darstellung, keine falsche oder verlorene Auswahl/Scrollposition |
| V04 Modale/Popup | je geänderter Modaltyp längste DE-/EN-Beschriftung, Pflichtfelder, voller/leer/Fehlerzustand bei Mindestgröße; Kalender/Dropdown/Tooltip/Mehrmenü mitprüfen | Titel und Footer erreichbar, Body scrollbar falls nötig; kein verdeckter Bestätigungs-/Abbruchknopf oder abgeschnittenes Ziel; neue Phase erzeugt keine zweite Layoutzuständigkeit |
| V05 ESC/Fokus/Zurück | ESC zuerst im Eingabefeld/Dropdown/Modal, anschließend Zurück; Tab/Shift-Tab; vorhandene Flüsteraktion öffnet nativen Chat | sichtbarer Schließ-/Zurückweg, keine verlorenen nicht bewusst verworfenen Eingaben, keine verschluckten Bewegungs-/Chatkeys, keine verdeckte Tastaturfalle |
| V06 Combat | mit offenem betroffenen Modal und fokussierter Eingabe Kampf beginnen/beenden; vorhandene erlaubte Aktionen nur bewusst auslösen | vorhandene Schutz-/Fallbackregeln bleiben, keine neue automatische geschützte Aktion, keine Lua-/Protected-Aktionsfehler; Fokus/ESC nach Kampfende wieder sinnvoll |
| V07 Deep Link und Refresh | unbekanntes/altes/gelöschtes Ziel sowie gültiges Ziel während offener Bearbeitung, Netzwerkrefresh/Mouse-down während Auswahl | E.3.1: erklärter Abbruch oder sichere Wiederherstellung; kein Ersatzobjekt, kein Eingabeverlust, keine durch Refresh abgebrochene Klickaktion |

**Aufwand begrenzen, Abdeckung erhalten:** V01/V02 ergeben 12 Screens je neuem/betroffenem Hauptlayout (2 Sprachen × 3 Benutzer-Scales × Manager an/aus) bei Mindestgröße. V03 ergänzt vier Screens bei Standard/groß. Gleiche unveränderte Layoutteile dürfen auf zuvor abgenommene Belege verweisen; in jeder Phase die aktuelle Hülle und wenigstens den tatsächlich betroffenen Einstieg erneut kontrollieren. Alle veränderten Modaltypen nach V04 abdecken, nicht beliebige 16 Screens als Ersatz für einen fehlenden Zustand zählen. Bei P1 ohne neues Hauptlayout gelten die bestehenden Zielseiten als Prüfoberflächen. Der 1280×860/1,4-Screen-Fit-Fall aus P0 ist nach Änderungen am Hüllen-/Fitverhalten erneut zu prüfen; nicht passende Kombinationen sind dokumentierte Grenzen/Befunde, keine PASS-Screens.

**Je Phase protokollieren:** HEAD/Clientbuild, geänderte Ansichten/Handler, QA-Belegpfade, Locale, Monitor-/UIParent-/Fenstermaße und beide Scales, Manageroption und echte Providerzahl, Modal-/Focus-/Combat-Ergebnis, Pass/Fail je V01–V07, verbleibende Blocker. Screens nach P0-Namensschema, Interaktionen zusätzlich als kurze reproduzierbare Schritte oder Clip. Kein realer Kampfzustand wird durch einen Mock als erledigt erklärt; fehlen Nachweise, bleiben sie offen.

**Freigabekriterium:** V01–V07 und ihre Regressionen für den tatsächlichen Änderungsbereich bestanden, kein stilles Fallback auf anderes Objekt, keine verlorene Fachfunktion, keine neue Freigabe/Domainmutation. Neu entstandene oder verschlimmerte Größen-/Fokus-/Combatfehler vor Beginn der abhängigen Phase beheben oder den Unterstützungsumfang ausdrücklich neu entscheiden. Unveränderte, in P0 belegte Bestandsmängel außerhalb des Phasenumfangs bleiben mit Befund-ID und verantwortlicher Folgephase ausdrücklich offen; sie werden weder als PASS markiert noch erzwingen sie einen vorgezogenen globalen Layoutumbau in P1. Die Charakterreferenz und jede später vollständig umgebaute Ansicht müssen die für sie freigegebenen Größen-/Bedienkriterien erfüllen. Daten-/Identitäts-/Eingabeverlust im eigenen Phasenumfang ist kein tolerierter Bestandsmangel. P10 erweitert diese laufende Prüfung um den Gesamtworkflow und Zwei-Client-/Lastfälle; es verschiebt sie nicht ans Projektende.

## H. Abschließende Priorisierung

Aufwand als relative Implementierungsschätzung für vorhandene WoW-UI, ohne reale Clienttest-Wartezeiten: klein ≤1 Arbeitstag, mittel 2–4, groß 5–8, sehr groß >8. Keine Terminzusage; phasenübergreifende gemeinsame Grundlagen nicht mehrfach addieren. **★** = besonders hoher Nutzerwert bei voraussichtlich kleinem Aufwand. Schweregrade beschreiben UX-/Integritätswirkung, nicht nachgewiesene Schadensfälle.

| Problem | Seite | Schweregrad | Nutzerwirkung | Lösung | Aufwand | Technisches Risiko | Phase |
|---|---|---|---|---|---|---|---|
| Unbestätigte Client-/Größenannahmen | alle, Referenz Charaktere | hoch | falsche Schrift-/Modal-/Scaleplanung verursacht späte Umbauten | P0-Istbelege und kleine getrennte Layoutprobe vor Produktänderung | mittel | hoch ohne echte Prüfung | P0 |
| Unknown/stale Deep Link schließt Arbeit oder wählt Ersatzobjekt | Navigation/Inbox/Details | hoch | falscher Kontext oder verlorene ungesendete Eingaben | atomare Ziel-/Eingabeprüfung vor Page/CloseDialogs, verständlicher Abbruch | mittel | hoch | P1; je Fachphase nachtesten |
| Privates Charakterblatt hinter Settings | Meine Charaktere | hoch | eigener Besitz schlecht auffindbar | eigener Hauptpunkt mit kompatiblen Aliassen ★ | klein nach Router | mittel | P2 |
| Generische Datenrows und vermischte Suchresultate | Meine Charaktere | hoch | Werte/Quelle/Inventar schwer verständlich | Charakterblatt A + separate gespeicherte Gegenstandssuche | groß | hoch (Identität/Privacy) | P3 |
| Pauschale „Niemals geteilt“-Aussage vs separater Companionkanal | Charaktere/Diary/Companion | hoch | Datenwege werden missverstanden | präzise Community-/lokale Aufnahme-/Exportbeschriftung ★ | klein | mittel (Text muss Scope treffen) | P3/P9 |
| Herstellungskontext geht beim Handelsausflug verloren | Handwerk/Handel | hoch | ungesendete Anfrage nicht fortsetzbar | RAM-Rückkehrkontext, Revalidierung | mittel | hoch | P1/P7/P8 |
| Zahlreiche versteckte Tabs und alte Leerhinweise | Aktivitäten/Quests | hoch | Fähigkeiten nur indirekt auffindbar | kanonische Aufgabenansichten + alte Routenadapter | groß | hoch | P1/P5a–P5c/P6 |
| Board zeigt Vorschau statt sofortiger Aktionen | Aktivitäten | mittel | zusätzlicher Öffnen-Klick bei jeder Aufgabe | vorhandenes Aktionsdetail inline nutzen | mittel | mittel-hoch | P5a |
| Wochenserie nur auf Legacy-Termineseite | Aktivitäten/Geplant | mittel | gleicher Termin besitzt je Einstieg andere Möglichkeiten | „Wiederholen…“ im Eigentümerdetail ★ | klein nach P5a/P5b-Basis | mittel (Zeit/Revision) | P5b |
| UTC-Fallback empfohlen, Auswahl verborgen | Termineditor | hoch | bestimmte Ortszeiten nicht korrigierbar | Konvertierungsfehler erklären; sichtbares UTC erst nach separater fachlicher Prüfung, keine neue Option in Stufe 1 | klein für Fehlertext, Folgeaufwand offen | mittel | P5b; separate Fachentscheidung für UTC |
| Gruppenvorlagen nur im Leerzustand | Aktivitäten/Composer | mittel | bestehende lokale Vorlagen schwer nutzbar | Vorlage verwenden/verwalten im Composer ★ | klein–mittel | mittel | P5c |
| Wünsche beanspruchen zu viel dauerhafte Dashboardfläche | Heute | mittel | zentrale Aufgaben verlieren Priorität | kompakte Zusammenfassung und vorhandener Editor auf Bedarf, kein Pflichtformular | klein–mittel | niedrig–mittel | P5c |
| Viele Bereiche in einer Home-Liste | Heute | mittel | nächste Aufgabe geht unter | genau offene eigene Aufgaben, jetzt relevante Aktivitäten, nächste Termine | mittel | mittel (projektiert bestehende Daten) | P5c |
| Main-/Aktivchar und Privatnotiz-Empfänger komplex | Mitspieler | hoch | mögliches Missverständnis bei Zielperson | reale Zielnamen und getrennte öffentliche/private Abschnitte | mittel | hoch (bestehendes Verhalten erhalten) | P4 |
| Sechs Filter gleichzeitig | Mitspieler | mittel | Einstieg wirkt administrativ | Suche/Schnellfilter plus Erweitert | mittel | mittel | P4 |
| Hilfeanfrage und gleiche Quest unklar getrennt | Quests | hoch | falsche Erwartung von Bewerbung/Gruppe | drei klare Ansichten, Statuslabels und Direktspieler | mittel–groß | mittel-hoch | P6 |
| Einkaufslisten versteckt unter Aufträgen | Handwerk | mittel | vorhandenes Werkzeug schwer auffindbar | sichtbarer Einkaufslistenfilter/Link ★ | klein | niedrig–mittel | P7 |
| Material-, Mengen- und Rezeptfrische unklar | Handwerk | hoch | unbekannte Daten erscheinen als verlässliche Planung | Stück/Crafts trennen, unvollständig/alt direkt zeigen | mittel | hoch | P7 |
| „Erstellen“ als Dauertab, „Verwaltung“ technischer Begriff | Handel | mittel | eigene Angebote nicht unmittelbar erkennbar | drei Ansichten und globale Erstellen-Aktion ★ | klein–mittel | mittel | P8 |
| Alarmklick markiert nur gelesen | Handel/Inbox | mittel | Treffer muss erneut gesucht werden | vorhandenes Offerziel öffnen bzw. Snapshotstatus erklären | mittel | mittel | P8/P9 |
| Settings ist Buttonliste | Einstellungen | hoch | öffentliche/private Daten, Arbeit und Technik vermischt | direkte Kategorien, bisherige Setter | groß | hoch bei Privacy | P2 |
| Sechs Addontabs mit Versionstext | Addon Manager | mittel | Namen/Status werden eng, mehr Navigationsstufen | Liste + Statusdetail + gleicher Providerhost | mittel | hoch bei Fremdframes | P9 |
| Vollseitenskalierung statt echter Anpassung | alle, besonders Charaktere/Mitspieler | hoch | Schrift schrumpft, Details werden eng | gemeinsames Split-/Single-Layout, feste lesbare Schrift | sehr groß über alle Phasen | hoch | P0/P3, danach jeweilige Seite/P10 |
| Mehrfachhandler/Reparenting und verteilte Layoutbesitzer | technische UIbasis | hoch | Umbau kann effektive Aktionen verlieren | klarer Router/Owner; bewusste Themeoverrides erhalten | groß | hoch | P1/P5a–P5c/P10 |
| Leer-/disabled-/veraltet-Zustände uneinheitlich | alle | mittel | Spieler versteht nächste Aktion nicht | einheitliche Statuszeilen und konkrete Gründe ★ für erste Texte | klein je Bereich, gesamt mittel | niedrig–mittel | alle |

Verbindliche Reihenfolge: P0 Clientaufnahme/Probe und Größenfreigabe → P1 Navigation → P3 Charakterreferenz → P2 Menü/bestehende Settings → P4 Kontaktziele → P5a Liste/Detail → P5b Eigene/Termine → P5c Composer/PvP/Heute → P6 Quests → P7/P8 Handwerk/Handel → P9 Integrationen → P10 Gesamtabnahme. Visuelle Clientprüfung gehört zum Abschluss **jedes** Pakets. Ein vermeintlicher Quick Win darf die jeweilige Backendprüfung nicht umgehen.

## I. Vergleich mit Referenz-Addons

Recherche am **2026-11-09**, öffentlich zugängliche Primärquellen der Maintainer/Autoren bzw. Blizzard. Verglichen werden konkrete Muster. Die Bewertung und Übertragung auf ZENIAL sind **E**, keine behaupteten Testergebnisse der fremden Addons. Kein Referenzaddon wird installiert oder als neue Abhängigkeit vorausgesetzt.

| Referenz | Betrachtetes UI-Konzept und Quelle | Vorteil | Nachteil / Grenze | Relevanz und konkrete Empfehlung |
|---|---|---|---|---|
| ElvUI | thematisch gruppierte echte Optionen und Suche mit Sprung zum Einstellungsort, belegt im Maintainer-Code [General.lua](https://github.com/tukui-org/ElvUI/blob/main/ElvUI_Options/Game/Shared/General.lua), [Search.lua](https://github.com/tukui-org/ElvUI/blob/main/ElvUI_Options/Game/Shared/Search.lua) | Einstellungen haben einen erkennbaren Besitzer, gezielter Sprung statt Buttonsuche | große Optionsbäume können für Anfänger selbst komplex werden; AceConfig und Retail-Module nicht als Forever-Voraussetzung übernehmen | hoch für Settings: wenige direkte Kategorien, sichtbare vorhandene Regler; globale Einstellungssuche wäre spätere gesonderte Erweiterung, nicht Teil dieses Plans |
| Details! | dichte Zeilen plus kontextbezogene Umschalt-/Detailaktionen; Rechtsklick-Switch an Fenster/Zeile im Maintainer-Code [window_main.lua, z. B. BGFrame/lineScript](https://github.com/Tercioo/Details-Damage-Meter/blob/master/frames/window_main.lua) | viel Information bei wenig Fläche, Aktionen am betrachteten Kontext | Rechtsklick allein ist schlecht entdeckbar; hohe Informationsdichte nicht für private Charakterwerte geeignet | hoch für Listen/Mehrmenü: Hauptaktion sichtbar, seltene Aktionen kontextbezogen und zusätzlich per normalem Klick zugänglich; keine Rechtsklickpflicht |
| Auctionator | Suchzeile oben, gespeicherte Einkaufslisten links und Ergebnisse mit Preis/Name/Verfügbarkeit rechts; [Autoren-Projektseite](https://www.curseforge.com/wow/addons/auctionator), visuell geprüftes [Shopping-Bild von 2023](https://media.forgecdn.net/attachments/667/349/2023-screenshot-new-shopping-tab-3.png) | Such- und Listenaufgabe verständlich getrennt, Spalten unterstützen Vergleich | viele Symbolaktionen und Tabs im Beispiel; AH-Daten/Handelssystem nicht dieselben wie Communityangebote | hoch für Handel/Materialien: Suche und klare Ergebnisliste, gespeicherte Alarme als eigener Bestand, Materialkontext behalten. Kein AH-Scan/Kaufen/Preisfeed als neue Funktion |
| TradeSkillMaster | Gruppen bestimmen Gegenstände, Operationen die Arbeit; Crafting-/Shopping-Aufgaben am Gegenstandsbestand; [Maintainerdokumentation zu Operationen](https://support.tradeskillmaster.com/tsm-addon-documentation/tsm-addon-manging-operations) (Seitenstand 2022) | komplexe Arbeit bleibt am selben Gegenstand/Arbeitsbestand | generische Operationen und Konfiguration wären für Normalspieler zu abstrakt; keine aktuelle Forever-APIaussage aus der älteren Dokumentation ableiten | hoch für Handwerk: kohärente Rezept→Material→Anfrage-Aufgabe übernehmen; Operationensprache, Formelsystem und Automatisierung ausdrücklich nicht übernehmen |
| Altoholic | Accountübersicht als Vergleichstabelle, getrennte Such-/Charakterbereiche; [Autoren-Projektseite](https://www.curseforge.com/wow/addons/altoholic), visuell geprüftes [Account-Summary-Bild v9.x](https://media.forgecdn.net/attachments/388/238/altoholic_9x_1.jpg) | Charaktervergleich und Aggregationen ohne Loginwechsel gut scanbar | viele gleichrangige Spalten/Seiten; ältere Screenshots zeigen kein aktuelles Foreverlayout; fremde Daten-/Accountsharing-Fähigkeiten nicht übernehmen | sehr hoch für Charakteralternative B und klar getrennte gespeicherte Gegenstandssuche. Für ZENIAL ist Charakterblatt A gewählt; vorhandene private Snapshots und Scopegrenzen behalten |
| BetterBags | benannte Kategorien und Suche, Suche auch als sichtbare obere Leiste; [Maintainer-README: Search und Custom Categories](https://github.com/Cidan/BetterBags#search) | bekannte Gruppierung reduziert gemischte lange Listen; Suche bleibt am Inventar | komplexe Suchsyntax/Kategorienkonfiguration überfordert schnell; Itembewegungen/Rechtsklicktransfer sind andere Funktionen | mittel-hoch für Inventar: Taschen/Bank/Charakter als klare Gruppierung, Textsuche einfach; keine neue Suchsprache, Itemverschiebung oder fremde Sortierlogik |
| Questie | Quest als Kontext: Linksklick ins Questlog, Zusatzoptionen, Gruppenfortschritt am Tooltip; [Maintainer-README: Tracker/Communication](https://github.com/Questie/Questie#quest-tracker) | Aufgaben/Spielerinformationen dort, wo die Quest betrachtet wird | versteckte Modifier/Rechtsklicks und zusätzliche Daten-/TomTomvoraussetzungen sind keine Standardbedienung | hoch für Quests: passende Spieler direkt neben Quest und sichtbare gültige Aktionen; keine ungefragte Questdatenbank oder Wegweiserintegration |
| Blizzard UI | reduzierte Hauptflächen und kontextbezogene Anpassungen; [Blizzard: Updated UI and HUD](https://worldofwarcraft.blizzard.com/en-gb/news/23837944) mit offiziellen Bildern (2022) | vertraute WoW-Sprache, klare Basiselemente und direkte Auswahl | Retail-Editmode und native Technologien beweisen keine Foreververfügbarkeit; dekorative Dichte der alten UI nicht kopieren | hoch: vorhandene Blizzard-FontObjects, Tooltips, ESC/Close-/Auswahlkonventionen und Frame-Fallbacks nutzen; keine neue geschützte Interaktion |

**E – direkt mit vorhandener Architektur machbar:** sichtbare Hauptnavigation, Listen-/Detailaufteilung, Abschnitte, Filterprogression, eindeutige Primäraktion, klare Aktualitäts-/Privatlabels, vorhandene Dialoge/Provider wiederverwenden.

**V – zusätzliche Voraussetzungen oder gesonderter Scope:** fremde Addon-APIs, neue AH-Preisdaten, vollständiger Inventar-/Bankbrowser auch innerhalb gespeicherter Daten, Itembewegung, automatische Gruppenbildung, globale Einstellungssuche, neue Export-Teilverteilungen und Screenreaderintegration. Sie werden aus den Referenzen nicht als implizit genehmigte Features abgeleitet.

Die beiden betrachteten Bilder wurden tatsächlich geöffnet und visuell verglichen: Auctionator zeigt eine breite Einkaufslisten-/Ergebnisaufteilung mit vielen Zeilensymbolen; Altoholic eine Accounttabelle mit Level/Erholung/Geld/Spielzeit/letztem Login und zusätzlicher Bereichsnavigation. Übernommen werden die Trennung der Aufgaben und die Vergleichbarkeit, nicht deren Pixel, Quellen, Code oder Assetdateien. Die Bilder sind verlinkte Recherchebelege und werden nicht ins Addon gepackt.

## J. User Journeys mit tatsächlichen und geplanten Interaktionen

**Zählregel:** Ausgang ist eine geöffnete Heute-Seite im breiten Layout, ohne bereits offenen Dialog; Zielobjekt vorhanden, im sichtbaren Bereich/auf erster Ergebnisseite. Navigation, Zeilenauswahl, Schaltfläche und bewusstes Enter je 1. Dropdownwechsel = Öffnen + Auswahl = 2. Eingabefokus/Tippen wird separat je bearbeitetem Feld gezählt; dadurch keine Behauptung einer gesamten physischen Klickzahl. Optionale Filter, nötige Pagination und Scrollgesten kommen real hinzu. Neu sind eindeutige **Sollziele**, keine bereits implementierten oder in Nutzerstudien gemessenen Werte. Die folgenden Zahlen wurden gegenüber den endgültigen Wireframes konsolidiert; optimistischere optionale Inlineabkürzungen aus Teilanalysen sind nicht eingerechnet.

| Nr. / Aufgabe / Zielzustand | B: heutiger konkreter Weg | Alt N / Eingaben | E: geplanter konkreter Weg | Ziel N / Eingaben |
|---|---|---|---|---|
| J01 Neuer Spieler findet Mitspieler per Namen | Mitspieler; Suchtext, Ergebnisliste sichtbar | 1 / 1 Feld | Mitspieler; Suchtext, Ergebnisliste sichtbar | 1 / 1 |
| J02 Gefundenen Spieler anflüstern (Chatentwurf offen) | Mitspieler → Zeile → Flüstern | 3 / optional Suche | Mitspieler → Zeile → sichtbar benannter Flüsternbutton | 3 / optional Suche |
| J03 Anderen eigenen Charakter ansehen | Einstellungen → Meine Charaktere → Charakter | 3 / 0 | Meine Charaktere → Charakter | 2 / 0 |
| J04 Anderen erlaubten Char zum Main machen | Einstellungen → Meine Charaktere → Charakter → Main | 4 / 0 | Meine Charaktere → Charakter → Main | 3 / 0 |
| J05 Nichtaktuellen Charakter ausblenden | Einstellungen → Meine Charaktere → Charakter → Mehr → Ausblenden | 5 / 0 | Meine Charaktere → Charakter → Mehr → Ausblenden | 4 / 0 |
| J06 Charakterdaten endgültig löschen | Einstellungen → Meine Charaktere → Charakter → Mehr → Löschen → Bestätigung | 6 / 0 | Meine Charaktere → Charakter → Mehr → Löschen → Bestätigung | 5 / 0 |
| J07 Gespeicherten Gegenstand finden | Einstellungen → Meine Charaktere; kombinierter Suchtext | 2 / 1 | Meine Charaktere → Gespeicherte Gegenstände; eigener Suchtext | 2 / 1; klare Ergebnistrennung statt Klickgewinn |
| J08 Utilitydaten übernehmen (geladen, kein Read-only) | Einstellungen → Meine Charaktere → Mehr → Übernehmen | 4 / 0 | Meine Charaktere → Mehr → Utilitydaten übernehmen | 3 / 0 |
| J09 Öffentliche Notiz ändern und speichern | Einstellungen → Charakterprofil → Speichern | 3 / 1–3 Felder | Meine Charaktere → Öffentliches Profil → Speichern | 3 / 1–3 |
| J10 Questmitspieler aus eigener Quest einladen | Quests → Quest → Spieler → Einladen | 4 / 0 | Quests → Quest → sichtbar benannte Zeilenaktion Einladen | 3 / 0 |
| J11 Lokalen Questgruppenvorschlag prüfen, einen einladen | Heute-Shortcut Questgruppen → Vorschlag → Mitglied → Einladen | 4 / 0 (über Hauptmenü 5) | Quests → Questgruppen → Vorschlag → Mitglieds-Zeilenaktion | 4 / 0 |
| J12 Explizite Hilfe für eigene Quest veröffentlichen | Quests → Quest → Hilfe suchen → Speichern | 4 / vorhandene Pflicht-/optionale Felder | Quests → Quest → Hilfe anfragen → Veröffentlichen | 4 / gleiche Felder; bestehende Anfrage wird bearbeitet |
| J13 Passende sichtbare Liveaktivität von Heute bewerben | Heutezeile → Bewerben im gemeinsamen Detail | 2 / optional Nachricht, Rolle ändern +2 | Heutezeile → Bewerben | 2 / gleiche Eingaben |
| J14 Fremde Aktivität im allgemeinen Board bewerben | Aktivitäten → Zeile → Öffnen → Bewerben | 4 / optional Nachricht/Rolle | Aktivitäten → Zeile mit direkt sichtbaren Aktionen → Bewerben | 3 / gleiche Eingaben |
| J15 Eigene Heute-Aktivität: Bewerber annehmen/einladen | Heutezeile → Bewerber → Annehmen und einladen | 3 / 0 | Heute-Antwortbedarf → Bewerber → Annehmen und einladen | 3 / 0; Fachprüfung unverändert |
| J16 Für sichtbare fremde Questanfrage Hilfe anbieten | Heute-Questhilfezeile → Hilfe anbieten | 2 / optional Nachricht | derselbe Heute-Detaileinstieg → Hilfe anbieten | 2 / gleiche Eingabe |
| J17 Neue Dungeon-Tageswünsche speichern, aktualisierte Startseite | Wünsche bearbeiten → Typ öffnen/wählen → Ziel öffnen/wählen → Speichern → Schließen | 7 / 0 | kompakte Wünsche: Bearbeiten → Typ öffnen/wählen → Ziel öffnen/wählen → Speichern → Schließen | 7 / 0; kein vorgetäuschter Klickgewinn |
| J18 Gruppe anlegen: vollständigen Editor öffnen | Heute: Aktivität erstellen → Weiter (mit vorhandenen Standardwerten) | 2 / zusätzliche Typ-/Zielwechsel je +2 | Heute: Aktivität erstellen → Weiter | 2 / gleiche Wahlhandlungen; Veröffentlichen danach +1 |
| J19 Wochenserie mit Standardzahl erzeugen | Aktivitäten → Events → eigener Termin → Wochenvorlage → Vorschau → Erstellen | 6 / 0 | Aktivitäten → eigener sichtbarer Termin → Mehr → Wiederholen → Vorschau → Erstellen | 6 / 0; über geplante Unteransicht zusätzlich +1 |
| J20 PvP-Hilfe senden, Voraussetzungen erfüllt | Kopf PvP → Ruf vorbereiten → Angriff bestätigen → Hilfe rufen | 4 / optional Hinweis, Gegnerfreigabe +1 | Kopf PvP → Ruf vorbereiten → Angriff bestätigen → Hilfe rufen | 4 / gleich; keine Bestätigung entfällt |
| J21 Handwerker mit Rezepttreffer wählen, Anfrage senden | Handwerk → Suchen/Enter → Rezepttreffer → Herstellung anfragen → Senden | 5 / Suche + optionale Anfragefelder | Handwerk → Suchen/Enter → Rezept-/Handwerkertreffer → im offenen Anfragebereich Senden | 4 / gleiche Felder; bei extra Herstellerwahl +1 |
| J22 Bestehende private Einkaufsliste ansehen | Handwerk → Aufträge → Alle Einkaufslisten → Liste | 4 / 0 | Handwerk → Aufträge → Einkaufslistenfilter → Liste | 4 / 0; auffindbarer statt versteckter Zugang |
| J23 Materialanbieter kontaktieren | Handwerk → Aufträge → Alle Einkaufslisten → Liste → Zutat → Angebote suchen → Angebot → Flüstern | 8 / 0, Nachricht nicht gesendet | Handwerk → Aufträge → Einkaufslisten → Liste → Zutat → Angebote → Angebot → Flüstern | 8 / 0; Gewinn ist gesicherter Rückweg |
| J24 Nach Handelsausflug ungesendete Herstellung fortsetzen | `Navigate` löscht `craftOrderContext`; Fortsetzen danach deaktiviert | kein durchgängiger Rückweg; keine fiktive Klickzahl | aktuelles Handelsdetail → Zurück zur Herstellung, Eingaben revalidiert | 1 / 0 ab Handelsdetail |
| J25 Eigenes aktives Angebot pausieren | Handel → Verwaltung → Angebot → Pausieren | 4 / 0 | Handel → Meine Angebote → Angebot → Pausieren | 4 / 0 |
| J26 Angebot veröffentlichen, Standardwerte brauchbar | Handel → Erstellen → Veröffentlichen | 3 / Gegenstand 1, Preis 1–3 Felder, Notiz optional | Handel → Angebot erstellen → Veröffentlichen | 3 / gleiche Felder; Vorschlagswahl ggf. +1 |
| J27 Handelsalarm aus Textsuche speichern | Handel; Suchtext → Suche speichern | 2 / 1 | Handel; Suchtext → Suchalarm speichern | 2 / 1 |
| J28 Pausiertes Angebot erneut veröffentlichen | Handel → Verwaltung → Angebot → Erneut anbieten → Veröffentlichen | 5 / optionale Änderungen | Handel → Meine Angebote → Angebot → Erneut anbieten → Veröffentlichen | 5 / gleiche Eingaben |
| J29 Private Kontaktnotiz speichern | Mitspieler → echter Kontakt → Notiz speichern | 3 / 1 | Mitspieler → Kontakt → Notiz speichern (Empfänger sichtbar) | 3 / 1 |
| J30 Neue private Kategorie definieren | Einstellungen → Private Kontaktkategorien → Hinzufügen | 3 / 1 | Mitspieler → Kategorien verwalten → Hinzufügen | 3 / 1 |
| J31 Begegnungsverlauf ansehen | Mitspieler → Kontakt → Social Diary | 3 / 0 | Mitspieler → Kontakt → Begegnungen/Social Diary | 3 / 0; Kontext erhalten |
| J32 Addoneinstellung öffnen, Manager-Shortcut an und Provider bereit | Addon Manager → Addon-Tab | 2 / 0; vom Zielprovider ggf. weitere eigene Schritte | derselbe Manager-Shortcut → Addonliste | 2 / 0; ohne Shortcut Settings→Integrationen→Manager→Addon =4 |

Am fremden Request lautet der geplante Text „Hilfe anbieten“, am eigenen Request „Helfer verwalten“. Fehlender Pflichtwert, andere Kategorie, zusätzliche Listen-/Filterseiten und Netzwartezeit verändern die reale Aufgabe; sie werden bei Clientabnahme separat protokolliert. Diese Tabelle soll überprüfbare Verbesserung zeigen und keine pauschale Reduktion aller Abläufe behaupten.

## K. Abdeckung, Nachweise und Fortsetzung

### K.1 Quellcode-Abdeckung der Oberflächen

- **Hülle/Navigation/Design:** UX, UXCreate, UXViews, UXLayout, UIState, UI, Theme, ThemeCommunity, ResponsiveUI, Locale und TOC; Includes, Reparenting, sichtbare/verborgene Controls und effektive Handler betrachtet.
- **Fachflächen:** sämtliche UXPage*-Builder und UXMembers/MemberGroups/Groups/Quests/Crafting/Trade/Sessions, Home, ActivityDetails/Archive, ScheduledGroupsUI/SchedulePickers, AccountOverviewUI, SocialDiaryUI, CategorySettingsUI, ProfessionHistoryUI, PvPHelpUI; eigene/andere/leer/alt-Zustände in A.6/A.7.
- **Zusatzflächen:** UXAddons, UXNotices, NoticeUI, NotificationInboxUI, NetworkSetup, CompanionUI, Launcher/LauncherSpec, CommunityMap/XML und UpdateNotice. Ergänzende native Settings-Launcherfläche aus `Launcher.buildPanel:346` zeigt Titel/Version/Beschreibung/Öffnen und optional einen vom jeweiligen Addon angebotenen Wizard. Community.LauncherSpec bietet keinen eigenen Wizard. Diese Registrierungsfläche bleibt ein kompatibler Einstieg, keine zusätzliche Hauptseite.
- **Technische Frames ohne normale Bedienansicht:** Companion-Pixelstreifen (`CompanionPixel.lua:47`, Tooltipstrata, Maus aus) ist sichtbarer Transport und darf durch neue Hülle nicht verdeckt werden. CompanionQuestAreas benutzt einen unsichtbaren nativen POI-Messframe, CompanionProgress/WhisperGuard/AccountPreferences Ereignisframes; sie werden nicht als zusätzliche Menüseiten behandelt. Export-/Sampling-/Keyboardverhalten bleibt unverändert.
- **Verfolgte Daten-/Aktionsabhängigkeiten:** AccountOverview/AccountPreferences/Main-Identität und Main-/Delete-/Preference-APIs, UXMemberGroups/Social/SocialCategories/SocialDiary/History, QuestHelper/QuestGroups, ActivityBoard/ActivityParty/GroupFinder/SessionPlans/ScheduledGroups/ScheduleTime/PvPHelp, RecipeSearch/ProfessionScan/CraftOrders/MaterialPlanner/TradeManager/Items, Notifications, Adapter/WhisperGuard sowie CommunityDirectory/BattleNetTransport/CommunityMesh/Network3/Companion-Status und Exportgrenzen. Low-level Netzwerkprotokolle werden nicht neu entworfen; deren bestehende Schutzfunktionen sind technische Grenzen.
- **Migrationen:** RealmMigration/ForeverLiveMigration sind bestehende Initialisierungs-/Backupabhängigkeiten, keine neuen UX-Workflows. Vorhandene Backups werden über Diagnose verwaltet. Keine neue Migrationsaufgabe allein wegen des Redesigns.

### K.2 Tatsächlich ausgeführte und noch offene Prüfungen

**Historisch in der Erstfassung durchgeführt:** Regeln/Auftrag gelesen; Remote-main per Fetch und ls-remote bestätigt; sauberer Community-Ausgangszustand; neuer Branch; statische Aufruf-/TOC-/Handleranalyse durch Hauptagent und zwei fachlich getrennte Sol-Agents. Kritische Behauptungen zu Materialrückweg, Accountguards, öffentlichem Profil, Companionexport, UTC-Fehlern und finalem Aktivitätsmodal vom Hauptagenten im Quellcode gegengeprüft. Primärquellenvergleich und zwei tatsächliche Screenshot-Sichtungen in I.

**Historischer Baseline-Harness der Erstfassung (damals auch vom Hauptagenten bestätigt, 5/5 PASS, Exit 0; in dieser reinen Dokumentrevision nicht erneut ausgeführt):** fünf vorhandene Suiten über frische `lupa.lua51.LuaRuntime` je Datei geprüft: `test_account_overview.lua`, `test_community_member_group_actions.lua`, `test_quest_helper_default_view.lua`, `test_social_diary.lua`, `test_social_categories.lua`. Diese Tests prüfen bestehendes Verhalten und ergeben keine Freigabe der noch nicht gebauten Zieloberfläche. Ein erster Versuch des Workers mit systemweitem lua.exe scheiterte vor Addonprüfung am fehlenden Lua-5.1-`setfenv`; das ist durch Nutzung des vorhandenen Lua51-Harness geklärt, kein behaupteter Produktfehler.

**Unabhängiger Planreview der Erstfassung:** Frischer Sol-Agent, nur lesend: ein materieller Konflikt in der Allowlist des Herstellungskontexts; E.2 um quantityText/craftsText/tipGoldText ergänzt und konkreten Roundtriptest festgelegt. Danach dokumentarischer Abgleich mit den vorhandenen Eingabefeldern; keine weiteren wesentlichen offenen Punkte im Reviewbericht.

**In dieser Revision durchgeführt:** lokalen HEAD und Remote-main per ls-remote erneut bei 5189cdb/5.4.0 bestätigt; bestehendes Dokument und relevante Source zu `AccountOverview.Search`, vorhandenen Controls, `Navigate/Page/CloseDialogs`, `OpenActivity/OpenUpdate/OpenApplications` gelesen und durch einen Sol-Agenten lesend gegengeprüft. Plan ausschließlich dokumentarisch revidiert, nachgezählte Phasen/Tabellen/Querverweise kontrolliert und unveränderte Produktdateien überprüft. Keine neue Harnessausführung, kein Ingame-/P0-Prototypentest und keine neue Referenzrecherche behauptet. Die frühere Baseline ist historisch erhalten und ersetzt keine künftige Phasenabnahme.

**Offen für spätere Ausführung:** P0 und alle 12 Produktpakete P1/P3/P2/P4/P5a/P5b/P5c/P6/P7/P8/P9/P10 einschließlich phasenweiser visueller Forever-Abnahme, zwei reale Clients für Netz-/Peer-/Einladungsfälle, konkrete Layout-/Performancewerte, Nutzertests und tatsächliche Zielfluss-Klickzahlen. Kein Release-/Installations-/Deploymentcheck wurde als erfolgreich ausgegeben. Das große Workspace-check.py wurde hier nicht gestartet.

### K.3 Wiederaufnahmeprotokoll für jede spätere Phase

Bei Wiederaufnahme zuerst Branch/HEAD/Status mit diesem Abschnitt abgleichen, geänderte Basis berücksichtigen und den letzten abgeschlossenen Status lesen. Danach genau die nächste offene Phase bearbeiten. Nach jedem belastbaren Teilergebnis aktualisieren:

```text
Phase: Pn / Aufgabe:
Status: offen | in Arbeit | geprüft | blockiert (konkreter Grund)
Basis-HEAD / aktueller HEAD:
Geänderte Dateien (Community / Harness getrennt):
Letzte tatsächlich ausgeführte Harnessprüfung + Ergebnis:
Clientabnahme V01–V07: Belege, reales Größen-/Scale-/Locale-/Managerprofil, Pass/Fail/offen:
Unveränderte P0-Befunde außerhalb Phasenumfang: ID + zuständige Folgephase:
Offene Risiken / benötigte Freigabe:
Nächster konkreter Schritt:
```

**Freigabepunkt:** Charakterlayout A und die acht Hauptbereiche sind festgehalten, B bleibt Vergleich. Noch ausstehend sind Ausführungsfreigabe für P0, dessen tatsächliche Client-/Größenergebnisse und danach Freigabe des bestätigten Layout-/Unterstützungsrahmens vor Produktumsetzung. Interne neue Settings oder eine neue sichtbare UTC-Auswahl sind kein Bestandteil dieser Freigabe; dafür wäre eine separate fachliche Prüfung nötig. Dieser Analysebranch enthält bis dahin ausschließlich dieses lokale, uncommittete Planungsdokument.

#### K.3-Einträge der Umsetzung (2026-11-09)

```text
Phase: P0 / Vorbereitung (Probe + QA-Vorlage)
Status: in Arbeit – Werkzeug fertig, Clientausführung durch Nutzer offen
Basis-HEAD: Community 5189cdb; Harness wow ux-redesign/p0-p1-harness 43281f1
Geänderte Dateien: Harness _dev/addons/ZenialCommunity/p0/{P0-QA.md, ZenialCommunityP0Probe/*}; Community keine
Letzte Harnessprüfung: Probe Lua51-Syntax + Mock-Smoke ohne Lua-Fehler (keine Layoutaussage)
Clientabnahme: offen; Probe in D:/World of Warcraft/_forever_/Interface/AddOns/ZenialCommunityP0Probe installiert
Nächster Schritt: Nutzer führt P0-01..P0-05 nach P0-QA.md aus, P0-05-Entscheid freigeben

Phase: P1 / Navigation, Legacy-Aliase, Rücksprungschutz
Status: geprüft (Harness) – Clientabnahme ausstehend (Nutzerentscheid: P1 vor P0-Ergebnis)
Basis-HEAD / aktueller HEAD: 5189cdb / f766bdd (Branch ux-redesign/p1)
Geänderte Dateien Community: neu UXNavigation.lua (+TOC nach UXCreate.lua); UXLayout, UXCreate, ActivityDetailsUI, UXNotices, UXGroups, AccountOverviewUI, SocialDiaryUI, UXViews, ProfessionHistoryUI, UXAddons, UXSessions, CommunityHomeUI, UXTrade, UXPageCraft, UXCrafting, Locale
Geänderte Dateien Harness (7bf2611): neu test_community_navigation_deeplinks.lua, test_community_craft_return_context.lua; angepasst test_community_home.lua (Link bei offenem Editor abgelehnt), test_community_compact.lua (activities/archive→activities), test_community_social43.lua (Fixture: vollständiger Teilnehmer)
Letzte Harnessprüfung: 119/119 PASS (alle test_community*, notifications, material_planner, scheduled_groups, quest_, session_plans, pvp_help, release40, ui_flow, account_overview, social_, history, addon_manager, launcher, trade_item, startup, update_notice, smoke)
Entscheidungen: Navigate gibt true/false,reason zurück; Sidebar bleibt ungeschützt (auch Quests-Tab); characterKey gegen AccountOverview.List(); Kontext bei gescheitertem Return behalten; OpenAddonManager bei unsaved-input Meldung+true; modale Editoren dirty wenn sichtbar; settings/notifications|advanced, activities/archive = unknown-view bis P2; Toast nicht erneut zeigen
Clientabnahme V01–V07: offen (V05/V07 Schwerpunkt); installiert in D:/World of Warcraft/_forever_/Interface/AddOns/ZenialCommunity, Backup ZenialCommunity-backup-20261109-234430
Bekannte Befunde außerhalb P1: Sidebar und Fenster-Schließen verwerfen offene Editoren weiterhin (→ P2/V05); OpenPrivateCategories ruft CloseDialogs ungeschützt
Nächster Schritt: P0 im Client, dann G.4 für P1; danach P3 nach P0-Freigabe
```

```text
Phase: P0 / Clientscreens + Web-Simulation der Matrix (2026-11-10)
Status: in Arbeit – Layoutteil simuliert, P0-01 und P0-05-Verhalten im Client offen, P0-05-Entscheid beim Nutzer
Belege: _dev/addons/ZenialCommunity/p0/*.png (16 Produktansichten deDE, Fenster 1279×858 laut SavedVariables, Manager an); Probe-Screens 900×610/1060×690/1280×860 (Nutzer, im Chat)
Werkzeug: _dev/addons/ZenialCommunity/p0/web/probe.html (1:1-Geometrieport der Probe + U.Layout-Formel), Schrift an 11 Client-Stringbreiten kalibriert (max. 1,9 % Fehler); 120 Zustände in Chrome gemessen, Abgleich mit allen drei Probe-Screens stimmig
Ergebnis: _dev/addons/ZenialCommunity/p0/P0-WEB-ERGEBNIS.md – Benutzer-Scale ändert das logische Layout nicht (nur Fit/Pixelschrift); Kopf+Filter 88; 1060×690 breit mit Liste 280 kürzt alle Untertitel und nur 1 Metrikspalte; Mehr-Menü feste Breite 120 schneidet DE ab; Produkt bei 900×610 Seitenfaktor 0,839 (+0,65 → 6,5 px Schrift); 1280×860×1,4 passt nicht (Negativfall)
Einschränkung: Simulation, kein G.4-Clientbeleg; UIParent nicht gemessen (nur Höhe ≥ 858 abgeleitet)
Nächster Schritt: Breakpoint 860 vom Nutzer entschieden (Variante b) und in E.4/Probe übernommen; P0-01 erledigt (UIParent 2133×1200, Build 1.60.1/70862, deDE, Scale 1; P0-QA §6); Clientmessung 1280×860 bestätigt Simulation (Geometrie exakt, Text ≤ 1,4 %); Probe: öffnen/verschieben/WASD bestätigt, ESC schließt Probe-Modal+Hülle gemeinsam (Probe-Fehler via UISpecialFrames, Produkt nutzt makeModal); offen im Produkt: ESC-Reihenfolge, Flüstern→Chat, Kampf
```

```text
Phase: P0 / Abschluss bis auf Freigabe (2026-11-10)
Status: geprüft – wartet auf Nutzerfreigabe des Größen-/Layoutrahmens (P0-WEB-ERGEBNIS.md, Abschnitt „P0-Ergebnis“)
Client: Wünsche-Dialog ESC Dropdown→Dialog bestanden; Flüstern→nativer Chat bestanden; Kampf mit offenem Aktivitätsdialog ohne Lua-Fehler, Bewegung frei, ESC schließt ganzes Addon (P0-B5)
Befunde: P0-B1 Mehr-Menübreite (P3), P0-B2 proportionale Seitenskalierung (P3 ff.), P0-B3 1280×860×1,4 Grenze, P0-B4 Modale über makeModal (ab P3), P0-B5 Kampf-ESC/Editorverlust (P2/P5c)
Nächster Schritt: Nutzerfreigabe des Rahmens, danach G.4 für P1 und Beginn P3
```

```text
Phase: P0 / abgeschlossen (2026-11-10)
Status: geprüft und vom Nutzer freigegeben: Fenster 900×610–1280×860, Scale 0,65–1,4 (ohne 1280×860×1,4), Breakpoint 860, Liste 280–340, Detail ≥ 504, Lücke 16, Kopf/Filter ≤ 120, Modal ≤ 560×480 bzw. Bildschirm − 48, Buttons 28/40
Nutzerauftrag: „stück für stück automatisch weiter“ – P3 beginnt; G.4-Clientabnahme für P1 wird mit der P3-Clientabnahme gebündelt (Abweichung von der Phasenschranke auf Nutzerwunsch)
Nächster Schritt: P3 analysieren und umsetzen
```

```text
Phase: P3 / Meine Charaktere (Layout A)
Status: geprüft (Harness) – Clientabnahme G.4 ausstehend (gebündelt mit P1)
Basis-HEAD / aktueller HEAD: f766bdd / 111368e (Branch ux-redesign/p3)
Geänderte Dateien Community: AccountOverviewUI.lua (Charakterblatt, Tabs Übersicht/Gespeicherte Gegenstände/Öffentliches Profil, Breakpoint 860, Zurück, Mehr- und Aufnahme-Popup mit Textbreite), UXLayout.lua (U.PageUsesNativeScale: Profilseite mit Unteransicht characters Scale 1; Wrapper um U.SetProfileView), Locale.lua
Geänderte Dateien Harness: test_account_overview.lua, test_community_profile_layout.lua angepasst; neu test_community_my_characters_p3.lua
Letzte Harnessprüfung: 88/88 PASS (test_community*, account_overview, companion_account, notifications, ui_flow, smoke); neue Suite 40× wiederholt ohne Fehler (Worker meldete einmaligen nicht reproduzierbaren Abbruch)
Verhaltensänderungen: Namenssuche filtert nur Charaktere; Itemsuche nur im Tab Gespeicherte Gegenstände (leere Suche ohne Treffer); Aufnahme-Checkboxen im Popup „Aufnahmeoptionen“; Guards/Main/Hide/Delete/Import unverändert
Risiken für Clientabnahme: echte Textbreiten/Zeilenhöhen; bei 900×610 nur ca. 198 Höhe für Liste/Blatt (Summary + Fuß)
Nächster Schritt: Clientabnahme P1+P3 nach G.4, danach P2
```
```text
Phase: P2 / Einstellungen und Sidebar
Status: umgesetzt – Harness-Nachweis und Clientabnahme ausstehend
Basis-HEAD / aktueller HEAD: laut P2-Implementierung; hier nicht erneut geprüft
Geänderte Dateien (Community / Harness getrennt): laut Implementierung / laut Harness-Teilaufgabe
Letzte tatsächlich ausgeführte Harnessprüfung + Ergebnis: in diesem Dokumentationsschritt nicht ausgeführt; Harness-Nachweis steht aus
Clientabnahme V01–V07: offen; Clientabnahme P1+P2+P3 offen
Abweichung: P2 wurde vor Abschluss der P3-Clientabnahme G.4 begonnen und umgesetzt; gemäß Nutzerentscheidung werden P1, P2 und P3 gemeinsam abgenommen.
Offene Risiken / benötigte Freigabe: Clientabnahme nach G.4 ausstehend
Nächster konkreter Schritt: Harness-Ergebnis ergänzen, danach gemeinsame Clientabnahme P1+P2+P3 dokumentieren
```

