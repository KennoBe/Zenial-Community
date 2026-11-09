# ZENIAL Community – Aufgabenplan für Claude Code
**Thema:** Meine Charaktere, Main-/Twink-System und nach Spielern gruppierte Mitgliederliste  
**Ziel-Repository:** KennoBe/Zenial-Community  
**Ausgangsbasis bei Planung:** main, Version 5.3.0, Commit d07083d2f092 (09.11.2026)  
**Status:** Planung; noch kein Lua-Code umgesetzt.

## Arbeitsanweisung für jede neue Claude-Session
Der Nutzer wird einzeln anweisen: **„Setze aufgabe.md Punkt N um.“**

1. Vor dem Start AGENTS.md bzw. übergeordnete Repository-Anweisungen lesen. Den **aktuellen** Code und bereits abgeschlossene Punkte erneut prüfen; diese Planung verweist auf den Ausgangsstand und ersetzt keinen Code-Check.
2. **Nur den angeforderten nummerierten Punkt** implementieren. Keine Folgepunkte vorziehen und keine großflächigen Neben-Refactorings. Notwendige kleine Korrekturen begründen.
3. Bestehende WoW-Forever-Kompatibilität (Interface 16001 / Client 1.60.1) und vorhandenes Theme, Layout, Netzwerk, SavedVariables sowie Lokalisierung respektieren. Keine ungetesteten Retail-APIs oder zusätzlichen Abhängigkeiten einführen.
4. Änderungen nachvollziehbar und migrationssicher gestalten. Bestehende Einstellungen, Kontakte, Historien, Berufe, Rezepte, Notizen und Profilinformationen dürfen nicht verlorengehen.
5. Nach Umsetzung: geeignete Tests/Checks ausführen, ungetestete Ingame-Verhaltensweisen benennen, Akzeptanzkriterien prüfen und **nur den erledigten Punkt** in dieser Datei auf [x] setzen. Kurze Zusammenfassung der geänderten Dateien und verbleibender Risiken liefern.
6. Kein Release, kein Versionsbump und kein Push ohne ausdrückliche Aufforderung. Wenn der Nutzer einen Commit wünscht, nur relevante Änderungen dieses Schritts committen.
7. **Datenschutz:** Die private Accountübersicht (Gold, Inventar, Spielzeit, Rested XP) bleibt ausschließlich lokal. Diese Daten niemals in Community-Snapshots, öffentliche Präsenz oder andere Netzwerkpakete übernehmen. Öffentliche Main-/Twink-Zuordnungen bleiben an die bestehende Profil-/Netzwerkfreigabe gebunden; eine eigenständige Opt-out-Steuerung ist vorzusehen.

## Fachliches Zielbild
**A. Meine Charaktere:** Eine einzige gut sichtbare, responsive Seite für die eigenen Charaktere. Grunddaten automatisch lokal sammeln, optionales Inventar separat. Hauptcharakter wählen; Twinks, Klassen, Level, Gold, Berufe und Datenstand klar anzeigen.

**B. Mitgliederliste:** Standardmäßig **eine Zeile pro Spieleridentität (Main)** statt eine Zeile pro Charakter. Ist der Main offline, aber ein verknüpfter Twink online, erscheint die Gruppe als **„Online · spielt mit Twink <Name>“**. Die sichtbaren Echtzeitinfos (Klasse, Level, Ort, Layer) gehören ausdrücklich dem **aktiven Twink** und dürfen nicht als Main-Daten ausgegeben werden. Aufklappen zeigt bekannte Charaktere. Unverknüpfte Charaktere bleiben eigene Zeilen.

**Beispiel:**
- „KennoBe (Main) — Online · spielt Frostbeere (Twink)“
- „Aktiv: Frostbeere · Magier 32 · Westfall“
- Aufgeklappt: „KennoBe · Schamane 60 · offline“ und „Frostbeere · Magier 32 · online“
- Wird KennoBe selbst eingeloggt, ändert sich derselbe Haupt-Eintrag zu „Online · spielt Main“.

**C. Verlässlichkeit und Privacy:** Die Verbindung basiert auf den vorhandenen, von Addons deklarierten `linkMain`-/`linkAlts`-Daten, nicht auf einer verifizierten Battle.net-Account-ID. Das UI darf sie deshalb nicht als kryptografisch verifiziert darstellen. Keine heuristische Zusammenführung allein anhand gleicher Namen, Klassen, Gilden oder Community-Aliasse. Geltungsbereich Realm/Spielwelt **und** Fraktion beachten; bestehende Forever-Migration und Charakteridentität nutzen.

## Technische Ausgangslage (vor Umsetzung erneut prüfen)
- `Main.lua`: `normalizeAccount`, `Z.PublicLinks()`, `Z.SetMain()`, `Z.RemoveCharacter()`, `Z.ConfirmedMain()`; Main standardmäßig im selben Realm/Fraktions-Scope, `linkMain` ist Bestandteil des veröffentlichten Profils.
- `Core.lua`: `L.ScopeKey()`, `L.Identity()`, `L.Snapshot()`, Encode/Decode der Felder `linkMain`, `linkAlts`, `linkVersion`; Profil-/Sichtbarkeitseinstellungen.
- `Network3.lua`: öffentliche Bundles übernehmen `linkMain`, nicht zwingend `linkAlts`; keine öffentliche Übertragung privater Accountdaten.
- `UXMembers.lua`: `memberEntries()` baut charakterbezogenes Modell `entries/byKey`; `refreshMembers()` filtert/sortiert jede Charakterzeile einzeln; `U.memberKey` steuert Aktionen/Details/Notizen/Favoriten.
- `UXPageProfile.lua`: „Main & Twinks“ mit festen Koordinaten, unten versteckter „Account overview“-Button.
- `AccountOverview.lua` / `AccountOverviewUI.lua`: getrennte private Erfassung/Popup. `enabled=false` und `inventory=false` im Ausgangsstand.
- `ResponsiveUI.lua`, `UXLayout.lua`: generische automatische Umpositionierung. Profilseite ist nicht als eigenes responsives Layout konzipiert.
- `UXTrade.lua`: `refreshCharacters()` für die eigene Liste.
- `Zenial-Utility/Characters.lua`: eigenständige Account-Zeilen; Community liest bisher `ZenialUtilityDB.characters` optional für fehlende Einträge/Gold.
- WoW-Besonderheit: Der Main kann offline sein und ist eventuell nie mit Community beobachtet worden. **Keine gefälschten Main-Level/Klassen/Profile** erzeugen; dann nur belegbaren Main-Namen als Überschrift und aktive Twink-Infos anzeigen.
- Online-Presence wird bereits zeitlich begrenzt; alte Snapshots dürfen nicht durch Gruppenbildung plötzlich online wirken. Die bisherige 7-Tage-Gültigkeit bei `Z.ConfirmedMain()` beachten bzw. bewusst und getestet ersetzen.

---

## Punkt 1 – Profilnavigation und Überlappungen beheben
**Status:** [ ] offen  
**Ziel:** Es gibt einen sofort erkennbaren Einstieg „Meine Charaktere“ und keine überlappenden Steuerelemente mehr.

### Umsetzung
- In `UXPageProfile.lua` die Navigation „Main & Twinks“ zu „Meine Charaktere“ vereinheitlichen; auch Einstiege in den Einstellungen/Startseiten und `/zenial twinks`, `/zenial alts`, `/zenial account` konsistent weiterleiten.
- „Account overview“ nicht als unten versteckten Button belassen. Vorhandene Übersicht auf derselben Charakterseite erreichbar machen; spätestens in Punkt 3 wird sie vollständig integriert. Keine zweite gleichwertige konkurrierende Benutzerführung.
- Starre Spaltenkoordinaten, erklärende Textblöcke und Footer-Schaltflächen prüfen. Konkreten Überlappungsfehler in Profil-Settings/Charakterseite beheben; keine simplen `SetFrameLevel`-Kaschierungen.
- Responsive Reflow auf Profilseite ausdrücklich steuern, statt ausschließlich auf generische Footer-Heuristik zu setzen. Bei kleiner Fensterhöhe ggf. eigener Scrollbereich.
- Texte auf Deutsch mit vorhandener Lokalisierung; keine unübersetzten englischen Titel im deutschen UI.

### Akzeptanztests
- Standard 1060×690, Mindestgröße 900×610, verschiedene UI-Skalierungen: kein abgeschnittener oder überlappender Button, keine unbedienbaren Bereiche.
- Profil/Charaktere/Verbindung/Darstellung untereinander umschaltbar, keine UI-/Lua-Fehler.
- Alte Slash-Commands funktionieren weiter.
- Keine Änderung am Netzwerk oder an privater Datenerfassung in diesem Punkt.

## Punkt 2 – Lokale Grunddatenerfassung ohne Konfigurationshürde
**Status:** [ ] offen  
**Ziel:** Der Spieler sieht nach Nutzung eigener Charaktere ohne versteckte Aktivierungsschritte sinnvolle lokale Daten.

### Umsetzung
- In `AccountOverview.lua` bei **Neuinstallationen** lokale Basisdaten standardmäßig sammeln: Gold, Klasse, Level, letzte Aktualisierung, XP/Rested XP; bestehende Accountdaten (Realm, Fraktion, Name, letzter Login, Berufe) wiederverwenden.
- Bereits ausdrücklich deaktivierte Alt-Konfigurationen **nicht** stillschweigend einschalten. Da der Alt-Wert `enabled=false` bislang sowohl Default als auch Nutzerentscheidung sein kann, eine saubere Migration mit Konfigurations-Marker/kurzem Einmalhinweis oder bewusst konservativem Alt-Verhalten vorsehen.
- Taschen-/Bankinventar bleibt **opt-in**. Bank nur bei geöffneter Bank erfassen. Keine neuen Hintergrundabfragen gegenüber anderen Spielern.
- Spielzeit: Existierenden `TIME_PLAYED_MSG`-Pfad prüfen. `/played` nur dann automatisieren, wenn dies auf Forever zuverlässig, ohne störende Chat-Ausgabe und mit sauberem Throttling möglich ist; sonst klare „nur nach /played“-Kennzeichnung.
- Quelle und Zeitstempel pro Datenfeld sauber speichern; unbekannt/alt ist nicht gleich 0. Schutz bei Ladezeit und Nullwerten beibehalten.
- Schema-/SavedVariables-Migration ohne Verlust bestehender Snapshots, Rückwärtskompatibilität wenn möglich.

### Akzeptanztests
- Frischer Nutzer: Grundwerte nach Login verfügbar; kein zusätzlicher „Aufzeichnung einschalten“-Schritt.
- Bestehender Nutzer mit deaktivierter Erfassung: keine unbemerkte Änderung.
- Taschen/Bank bleiben ohne Einwilligung aus; andere Spieler erhalten keinerlei private Daten.
- `/reload`, Charwechsel und ältere SavedVariables erzeugen weder Datenverlust noch Lua-Fehler.

## Punkt 3 – „Meine Charaktere“ als hochwertige integrierte Oberfläche
**Status:** [ ] offen  
**Ziel:** Die bisherige reine Textliste und die separate 650×550-Popup-Accountübersicht werden durch eine einheitliche Charakterverwaltung ersetzt.

### Umsetzung
- Charakterliste mit Klassenicons, Name, Main/Twink-Badge, Level, Realm, Fraktion und „zuletzt aktualisiert“. Aktueller Charakter sowie Main deutlich markiert.
- Oben kompakte Kennzahlen: bekannte Charaktere, **zuletzt erfasstes** Gold insgesamt, ggf. Berufe. Unbekannte/stale Werte erkennbar, Summen nicht als live darstellen.
- Charakter auswählen → Detailbereich: Basisdaten, Rested XP, Spielzeit soweit vorhanden, Gold, Berufe, optionale Taschen/Bank und Gegenstandssuche. Responsive statt fester Popup-Größe.
- Realm-/Fraktionsfilter und Text-/Item-Suche sinnvoll platzieren; keine Filter, die ohne Kontext leere Listen vortäuschen.
- „Als Main festlegen“ prominent am gewählten Twink, gefährliche Aktionen unter sekundärem Menü. **„Aus Übersicht ausblenden“** (nicht destruktiv) klar von **„Charakterdaten löschen“** (destruktiv, Bestätigung mit konkreten Folgen) trennen. Vorhandenes `Z.RemoveCharacter` löscht mehr als den Anzeigeeintrag: nicht heimlich umdefinieren.
- Hauptcharakter kann manuell geändert werden; automatischer Vorschlag bleibt nachvollziehbar.
- Theme-/Localization-Helfer nutzen, keine isolierte neue Designwelt.

### Akzeptanztests
- Keine doppelte Accountübersicht/Überlagerung.
- Mainwechsel, Details, Suche, Filter, Ausblenden/Einblenden, Löschbestätigung korrekt.
- Kleine Fenster, langer Name, viele Charaktere, unbekannte Daten und 0 Gold ordentlich dargestellt.
- Keine Übertragung von Gold/Spielzeit/Inventar.

## Punkt 4 – Zenial Utility optional halten und Datenquellen entkoppeln
**Status:** [ ] offen  
**Ziel:** Für Community-Charakterübersicht ist Zenial Utility zu keinem Zeitpunkt erforderlich.

### Umsetzung
- Prüfen, welche Felder Utility heute liefert (`ZenialUtilityDB.characters`: Name, Realm, Fraktion, Klasse, Level, Gold, Zeitstempel) und ob Community diese selbst erfassen kann.
- `AccountOverview.lua` so gestalten, dass **Community die führende lokale Datenquelle** ist. Keine Doppelzählung, keine fortlaufende undurchsichtige Überschreibung aktueller Community-Werte durch Utility.
- Für Utility-Bestandsnutzer ggf. eindeutige, **optionale, einmalig wiederholbar sichere** Übernahme („Daten aus Zenial Utility übernehmen“) anbieten; Quelle/Zeitstempel anzeigen. Nur vorhandene Daten lesen; niemals Utility-SavedVariables schreiben.
- Eindeutige Zuordnung über normalisierten Charakter, Realm und Fraktion; unsichere/mehrdeutige Treffer nicht zusammenführen.
- Ohne Utility funktioniert alles gleich; keinen Installationshinweis als Pflicht, keinen Laufzeitfehler.

### Akzeptanztests
- Nur Community installiert; beide Addons installiert; Utility später entfernt.
- Nie doppelte Charaktere/Goldbeträge; neuerer gültiger Community-Snapshot bleibt führend.
- Keine zirkuläre Abhängigkeit und keine Änderungen im Utility-Repository nötig.

## Punkt 5 – Identitäts-/Gruppierungsmodell für die Mitgliederliste (noch keine neue UI)
**Status:** [ ] offen  
**Ziel:** Zu bestehenden charakterbezogenen Member-Daten entsteht ein **reines abgeleitetes Gruppierungsmodell**. Bis Punkt 6 bleibt die sichtbare Liste unverändert.

### Umsetzung
- Bestehendes `S.memberEntries()` und `S.memberModel.byKey` für alte Codepfade, Kontakte, Netzwerk, Chat-/Whisper-Aktionen, Favoriten, Notizen und Historien erhalten.
- Separaten Builder (z. B. `S.memberGroups()` oder eigenes kleines Modul) für eine Gruppe pro gültiger Hauptcharakter-Identität erstellen, mit Feldern wie `groupKey`, `mainName`, `mainMember` (optional), `members[]`, `activeMembers[]`, `activeMember`, `online`, `lastSeen`, `isOwn`. Tatsächliche Member-Keys separat erhalten.
- Link aus `Z.PublicLinks()` / `Z.ConfirmedMain()` / frischen gültigen `peer.data.linkMain` verwenden. Immer World/Realm, Fraktion, valide Identität, Aktualität und gegebenenfalls `linkVersion` berücksichtigen. Keine Zusammenführung über identische Anzeige-/Rufnamen oder unterschiedliche Realms/Fraktionen hinweg.
- Fehlende Main-Präsenz: **virtueller Anzeigeanker**, aber niemals fiktiver kontaktierbarer Peer, keine erfundene Klasse, Level, Online-Presence oder Profildaten. Wenn Twink online, Gruppe online; aktive Infos kommen von diesem Twink.
- Konflikte, veraltete Zuordnung, widersprüchliche Links, Selbstverweise/Zyklen, blockierte/ausgeblendete Charaktere: sicherer Fallback als eigene Einzelgruppe. Nicht „identitätsverifiziert“ behaupten; diese Zuordnung ist nur durch teilnehmende Addons deklariert.
- Der aktuell eigene Charakter und bekannte eigene Twinks dürfen aus lokalen Accountdaten zu einer eigenen Gruppe werden; diese privaten Daten nicht an andere Nutzer senden.
- Mehrere gleichzeitig online erscheinende Twinks: alle Online-Kandidaten im Modell erhalten; bevorzugten aktiven Kandidaten deterministisch nach frischer Präsenz wählen, aber übrige nicht verbergen.
- Cache-Invalidierung auf Profile-/Linkänderung, Presence-Timeout, Blockieren/Entblockieren, Mainwechsel und alternde Links; kein teurer Full-Rebuild pro Frame.
- Benannte Testfälle mit deterministischen Beispieldaten abdecken, wenn sich das ohne ungeeignete WoW-API-Mocks machen lässt.

### Akzeptanztests
- Main online; Main offline/Twink online; nur Twink bekannt; weder Main noch Link bekannt; zwei Twinks online; Link älter als zulässiges Zeitfenster.
- Gegensätzliche Links und doppelte Anzeigenamen werden nicht falsch zusammengefasst.
- Die bisherige Mitgliederliste funktioniert unverändert weiter.
- Keine Netzwerkerweiterung oder neue private Freigabe.

## Punkt 6 – Mitgliederliste standardmäßig pro Main anzeigen
**Status:** [ ] offen  
**Ziel:** Standardmäßig eine sichtbare Zeile pro Spieleridentität, nicht pro Twink. Wahlweise bisherige Einzelcharakter-Ansicht.

### Umsetzung
- `UXMembers.lua` verwendet für die *sichtbare Liste* das Gruppierungsmodell aus Punkt 5. Die Rohdaten/Member-Aktionen bleiben kompatibel.
- Eintrag zeigt primär **Main-Name**. Status:
  - Main aktiv: „Online · spielt Main“.
  - Main offline, ein Twink aktiv: „Online · spielt <Twinkname>“ (als Gruppensignal; Main nicht als selbst eingeloggt ausgeben).
  - Niemand online: „Offline · zuletzt gesehen …“ bezogen auf die vorhandenen Daten.
- Bei aktiven Twinks direkt in Unterzeile deren **Name, Klasse, Level, tatsächlichen Standort/Layer** anzeigen, niemals irreführend die alte Main-Position oder -Klasse.
- Falls Main noch nie als Peer bekannt ist: Main-Namen als Anker verwenden, aber nur die nachweislich vorhandenen Twink-Daten anzeigen.
- Gruppen optional aufklappbar; darin Main und bekannte Twinks mit jeweils eigenem Online-/Offline-Status. Ruhiges, kompaktes Design mit Klassenicons, Status und erkennbaren Einrückungen.
- Umschalter „Nach Hauptcharakter gruppieren“ (standardmäßig an) / „Alle Charaktere einzeln“. Einstellung lokal persistieren, nicht automatisch veröffentlichen.
- Online-Filter bezieht sich auf **mindestens einen online befindlichen Gruppencharakter**. Suche nach Main- oder Twinknamen führt zur Gruppe; nachvollziehbare Filterlogik für Klasse, Level, Berufe, Gilde, Favoriten und Kategorien. Wenn der Filter einen Twink trifft, den Treffer erkennbar machen.
- Sortierung Online zuerst funktioniert auf Gruppenebene. Zähler unterscheiden „N Spieleridentitäten“ und „M bekannte Charaktere“, soweit Gruppierung möglich; unbekannt/verknüpft nicht als garantierte reale Personenanzahl ausgeben.
- Keine Änderung an den Kontakt- oder Netzwerk-Snapshots; reine UI-Projektion.

### Akzeptanztests
- 1 Main + 3 Twinks erzeugt standardmäßig 1 Haupteintrag; Twink-Login macht diesen online.
- Wechsel Twink → Main / Twink → anderer Twink aktualisiert Anzeige und Detailzeile ohne Duplikate.
- Suche/Online-Filter/Klassenfilter/Favoriten/Sortierung sowie Zähler verhalten sich konsistent.
- Umschalten auf Einzelcharaktere bringt bisheriges Verhalten zurück.
- Keine flackernden Zeilen und keine veralteten Online-Anzeigen nach Timeout.

## Punkt 7 – Gruppendetails, Auswahl und Kontaktaktionen sicher anpassen
**Status:** [ ] offen  
**Ziel:** Auf eine Main-Gruppe zu klicken zeigt die Identität zusammen mit dem aktiven Twink; Aktionen treffen trotzdem den korrekten tatsächlichen Charakter.

### Umsetzung
- Auswahl von `groupKey` und konkretem `memberKey` sauber trennen. Bestehende `U.memberKey`-basierte Funktionen nicht blind auf virtuelle Gruppen-IDs umbiegen.
- Detailpane: Main-Überschrift, aktiver Charakter, bekannte Twinks mit Status, zuletzt bekanntem Level/Klasse/Ort sowie ggf. Berufsdaten gemäß bisheriger Sichtbarkeit.
- **Flüstern / Gruppe einladen / Kontaktieren** bei einer online Twink-Gruppe an den real erreichbaren **aktiven Twink**, nicht den offline Main und nie an den virtuellen Gruppenanker. Bei mehreren aktiven Charakteren eindeutige Auswahl bzw. klar benannte Zielperson.
- Offline-Kontakt: Aktionen korrekt deaktivieren oder expliziten Charakter wählen; keine stillen Aktionen an falschen Zielnamen.
- Favoriten, private Notizen, Kategorien, Historie, Social Diary und Gildenstatus sind aktuell **charakterbezogen**. Nicht automatisch zusammenkopieren oder löschen. Im Gruppen-UI klar zeigen, auf welchen Charakter eine Aktion wirkt. Such-/Favoritenfilter können passende Gruppen finden, auch wenn der Favorit ein Twink ist.
- Bestehende Navigation aus Mitgliedern, Handwerk, Quest-/Gruppenanfragen und Social-Ansichten erhalten.
- Blockierung/Privatsphäre: Geblockte Charaktere dürfen nicht durch alternative Gruppenansichten wieder auftauchen; keine unsichtbaren Daten in Tooltips.

### Akzeptanztests
- Einladen/Flüstern bei offline Main + online Twink verwendet Twinknamen.
- Notizen und Favoriten bleiben exakt am ursprünglichen Charakter.
- Gruppenwechsel, Detailansicht, Zurücknavigation und Auswahl nach Refresh bleiben stabil.
- Einzelcharakter-Modus bedient sich wie zuvor.

## Punkt 8 – Gesamttest, Performance, Bereinigung und Release-Vorbereitung
**Status:** [ ] offen  
**Ziel:** Alle 7 Punkte zusammenspielen; keine Regression in anderen Community-Funktionen.

### Umsetzung
- Alle relevanten Lua- und TOC-Änderungen reviewen, veraltete tote Popup-Pfade/unnötige UI-Duplizierungen entfernen, sofern sicher.
- Übersetzungen, Tooltips und Hilfetexte vervollständigen; keine unklaren englischen UI-Fragmente.
- Migrationspfade, alte SavedVariables, umbenannte Charaktere, unterschiedliche Forever-Realms/Rulsets, Fraktionen, fehlende Main-Snapshots, falsche/alte Links, gelöschte Charaktere, 90-Tage-Sichtbarkeitslimit und 7-Tage-Link-Ablauf prüfen.
- UI mit 900×610, 1060×690, anderer Skalierung, langen Namen, 1/10/100 bekannten Charakteren testen.
- Netzwerk- und Datenschutz-Audit: keinerlei Gold-/Inventar-/Spielzeitdaten werden veröffentlicht; bei Profil-Sichtbarkeit aus keine Community-Verknüpfung erzwungen. Keine verstärkte Netzwerkbelastung durch Gruppierungs-UI.
- Performance messen/prüfen: Gruppierungs-Cache, Refresh-Frequenz, List-Rendering, Aufklappstatus bei Updates, Speicherverbrauch.
- Wenn Test- oder statische Prüfskripte vorhanden sind, nutzen; neue minimale Tests nur bei sinnvollem Aufwand. Ohne laufenden Forever-Client Ingame-Ergebnisse ausdrücklich als **noch manuell zu prüfen** markieren.
- Erst danach Release-/Versionsvorschlag nennen; **nicht** automatisch releasen.

### Akzeptanztests
- Keine bekannten Lua-Fehler, keine neuen Pflicht-Abhängigkeiten, keine UI-Überlappungen.
- Main/Twink-Status und Kontaktaktionen sind in den beschriebenen Fällen korrekt.
- SavedVariables und Community-Features (Kontakte, Handwerk, Gruppen, Questhilfe, Social Diary, Karte, History) bleiben erhalten.
- Dokumentation und tatsächlich getestete Fälle nachvollziehbar.

---

## Definition of Done für jeden Einzelpunkt
- [ ] Nur der angeforderte Punkt wurde umgesetzt.
- [ ] Relevante alte Funktionen bleiben nutzbar.
- [ ] Datenmigration/Privatsphäre berücksichtigt.
- [ ] Keine neue Fehlerquelle durch fehlende Forever-APIs.
- [ ] Lokale Checks ausgeführt und manuelle Ingame-Tests bei Bedarf benannt.
- [ ] Abschlussantwort mit Änderungen, Tests und Rest-Risiken.
- [ ] Status des konkreten Punkts in aufgabe.md aktualisiert.

## Kommandos für getrennte Claude-Chats
1. **Setze aufgabe.md Punkt 1 um. Lies vorher AGENTS.md und den aktuellen Repo-Stand. Nur Punkt 1; prüfe die Akzeptanzkriterien und markiere ihn bei Erfolg als erledigt.**
2. **Setze aufgabe.md Punkt 2 um. Nur diesen Punkt, berücksichtige erledigte Schritte.**
3. **Setze aufgabe.md Punkt 3 um. Nur diesen Punkt, berücksichtige erledigte Schritte.**
4. **Setze aufgabe.md Punkt 4 um. Nur diesen Punkt, berücksichtige erledigte Schritte.**
5. **Setze aufgabe.md Punkt 5 um. Nur das Gruppierungsmodell ohne neue sichtbare Mitgliederliste.**
6. **Setze aufgabe.md Punkt 6 um. Verwende das Modell aus Punkt 5 und implementiere die Main-gruppierte Mitgliederliste.**
7. **Setze aufgabe.md Punkt 7 um. Richte Gruppen-Details und Kontaktaktionen korrekt auf den aktiven Twink aus.**
8. **Setze aufgabe.md Punkt 8 um. Gesamttest und Release-Vorbereitung, aber kein Release ohne meine Freigabe.**
