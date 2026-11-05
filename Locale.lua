local Z=ZenialCommunity

local locale=type(GetLocale)=="function"and GetLocale()or"enUS"
local german=locale=="deDE"

-- English is the source language. The reverse index keeps remaining German source
-- literals translatable while the UI moves to English keys without a flag day.
local DE={
    ["My guild"]="Meine Gilde",
    ["My guild only"]="Nur meine Gilde",
    ["Same guild"]="Gleiche Gilde",
    ["Member filter"]="Mitgliederfilter",
    ["Forget locally"]="Lokal vergessen",
    ["Withdraw and verify an active application before forgetting it."]="Aktive Anmeldung erst zurückziehen und abgleichen, bevor sie lokal vergessen wird.",
    ["This role has no scheduled slot."]="Für diese Rolle ist kein Platz vorgesehen.",
    ["Saved event starts in 30 minutes"]="Gespeicherter Termin beginnt in 30 Minuten",
    ["Saved event starts in 10 minutes"]="Gespeicherter Termin beginnt in 10 Minuten",
    ["Saved event starts now"]="Gespeicherter Termin beginnt jetzt",
    ["Saved state"]="Gespeicherter Status",
    ["Verification in progress"]="Abgleich wird durchgeführt",
    ["No direct route"]="Keine direkte Verbindung",
    ["Awaiting organizer response"]="Antwort des Veranstalters ausstehend",
    ["Queued operation"]="Aktion in Warteschlange",
    ["Verified with organizer"]="Mit Veranstalter abgeglichen",
    ["No confirmed response"]="Keine bestätigte Antwort",
    ["Event changed; request rejected"]="Termin geändert; Anfrage abgelehnt",
    ["Application limit reached"]="Anmeldelimit erreicht",
    ["Registration closed"]="Anmeldung geschlossen",
    ["Event unavailable"]="Termin nicht verfügbar",
    ["Publication withdrawn"]="Veröffentlichung zurückgenommen",

    ["Reported online; not directly reachable"]="Online gemeldet; nicht direkt erreichbar",
    ["Offline or unknown"]="Offline oder unbekannt",
    ["Scheduled"]="Termine",
    ["Scheduled event"]="Termin",
    ["Events"]="Termine",
    ["All scheduled events"]="Alle Termine",
    ["My scheduled events"]="Meine Termine",
    ["My scheduled applications"]="Meine Terminanmeldungen",
    ["Client local time"]="Lokale Clientzeit",
    ["Input timezone"]="Eingabezeitzone",
    ["Organizer"]="Veranstalter",
    ["Organizer role"]="Veranstalterrolle",
    ["slots"]="Plätze",
    ["Free roles: "]="Freie Rollen: ",
    ["Sunday"]="Sonntag",
    ["Monday"]="Montag",
    ["Tuesday"]="Dienstag",
    ["Wednesday"]="Mittwoch",
    ["Thursday"]="Donnerstag",
    ["Friday"]="Freitag",
    ["Saturday"]="Samstag",
    ["Date or time is invalid."]="Datum oder Uhrzeit ist ungültig.",
    ["Local time conversion is unavailable or this clock time does not exist. Use an explicit UTC time."]="Lokale Zeitkonvertierung fehlt oder die Uhrzeit existiert nicht. Bitte UTC explizit eingeben.",
    ["This local clock time occurs twice. Choose an explicit UTC time."]="Diese Ortszeit kommt zweimal vor. Bitte UTC explizit eingeben.",
    ["Local time conversion is unavailable."]="Lokale Zeitkonvertierung ist nicht verfügbar.",
    ["Scheduled revision limit reached."]="Revisionslimit für Termine erreicht.",
    ["Saved scheduled groups are unavailable. Data was preserved."]="Gespeicherte Termine sind nicht verfügbar. Daten wurden erhalten.",
    ["Scheduled event fields are invalid."]="Terminfelder sind ungültig.",
    ["Organizer role needs a slot."]="Die Veranstalterrolle benötigt einen Platz.",
    ["Scheduled storage is full (100 events). Archive or delete old drafts."]="Terminspeicher ist voll (100 Termine). Alte Entwürfe löschen oder Archivbereinigung abwarten.",
    ["Scheduled event changed or is no longer editable."]="Termin wurde geändert oder ist nicht mehr bearbeitbar.",
    ["Publishing scheduled groups is unavailable."]="Terminveröffentlichung ist nicht verfügbar.",
    ["Publish no more than ten upcoming events."]="Höchstens zehn kommende Termine veröffentlichen.",
    ["Scheduled event changed or is closed."]="Termin wurde geändert oder ist geschlossen.",
    ["Only unused private drafts can be deleted."]="Nur unbenutzte private Entwürfe können gelöscht werden.",
    ["No more than twenty recurrence templates."]="Höchstens zwanzig Wiederholungsvorlagen.",
    ["Choose one to four upcoming instances."]="Eine bis vier kommende Instanzen wählen.",
    ["Client timezone changed. Create a new recurrence template."]="Clientzeitzone wurde geändert. Neue Wiederholungsvorlage anlegen.",
    ["Events must start within ninety days."]="Termine müssen innerhalb von neunzig Tagen beginnen.",
    ["Recurrence preview changed. Review it again."]="Wiederholungsvorschau wurde geändert. Erneut prüfen.",
    ["Scheduled groups unsupported or not yet verified"]="Terminfunktion fehlt oder ist noch nicht bestätigt",
    ["Organizer offline or not directly reachable"]="Veranstalter offline oder nicht direkt erreichbar",
    ["Scheduled subscription storage is unavailable or full."]="Speicher für Terminanmeldungen ist nicht verfügbar oder voll.",
    ["Verify the event with its organizer before applying."]="Termin vor der Anmeldung mit dem Veranstalter abgleichen.",
    ["No active scheduled application to withdraw."]="Keine aktive Terminanmeldung zum Zurückziehen.",
    ["Application changed or event is closed."]="Anmeldung wurde geändert oder Termin ist geschlossen.",
    ["This role is already full. Use the waitlist."]="Diese Rolle ist bereits voll. Bitte Ersatzbank verwenden.",
    ["No application"]="Keine Anmeldung",
    ["Withdrawal pending"]="Rückzug ausstehend",
    ["Application pending"]="Anmeldung ausstehend",
    ["Saved state; verification pending"]="Gespeicherter Status; Abgleich ausstehend",
    ["Scheduled change saved."]="Terminänderung gespeichert.",
    ["Editing a published event invalidates existing applications. Participants must apply again."]="Änderungen entwerten bestehende Anmeldungen. Teilnehmer müssen sich neu anmelden.",
    ["Save a private draft, then publish it explicitly. Times are stored as UTC."]="Privaten Entwurf speichern, dann ausdrücklich veröffentlichen. Speicherung erfolgt in UTC.",
    ["%d events · page %d/%d"]="%d Termine · Seite %d/%d",
    ["Invalid scheduled data was rejected."]="Ungültige Termindaten wurden abgelehnt.",
    ["Select a scheduled event."]="Wähle einen Termin.",
    ["Public announcements do not confirm attendance. Participant names are visible only to the organizer."]="Öffentliche Ankündigungen bestätigen keine Teilnahme. Teilnehmernamen sieht nur der Veranstalter.",
    ["Delivery: "]="Übertragung: ",
    ["Previous"]="Zurück",
    ["Next"]="Weiter",
    ["Show archived events"]="Archivierte Termine zeigen",
    ["New event"]="Neuer Termin",
    ["Confirm participant"]="Teilnehmer bestätigen",
    ["Waitlist"]="Ersatzbank",
    ["Decline"]="Ablehnen",
    ["Publish"]="Veröffentlichen",
    ["Cancel event"]="Termin absagen",
    ["Weekly template"]="Wöchentlich",
    ["Local reminders run only while WoW and the addon are running."]="Lokale Erinnerungen funktionieren nur bei laufendem WoW und Addon.",
    ["Date and time: YYYY-MM-DD HH:MM"]="Datum und Uhrzeit: YYYY-MM-DD HH:MM",
    ["Save event"]="Termin speichern",
    ["Weekly instances: same organizer local time"]="Wöchentlich: gleiche Ortszeit des Veranstalters",
    ["Preview one to four future dates. New instances are private drafts with empty participant lists. No background recurrence."]="Eine bis vier kommende Termine vorab prüfen. Neue Instanzen sind private Entwürfe ohne Teilnehmer. Keine automatische Wiederholung.",
    ["Number of instances"]="Anzahl der Instanzen",
    ["Preview dates"]="Termine vorab prüfen",
    ["Create reviewed instances"]="Geprüfte Instanzen anlegen",
    ["Scheduled application changed"]="Terminanmeldung geändert",
    ["Scheduled participation updated"]="Terminteilnahme aktualisiert",
    ["Scheduled event changed; apply again"]="Termin geändert; erneut anmelden",
    ["Reminder for a saved event"]="Erinnerung an gespeicherten Termin",
    ["Applications"]="Bewerbungen",
    ["Private event"]="Privater Termin",

    ["Continue craft request"]="Herstellungsanfrage fortsetzen",
    ["Material planning"]="Materialplanung",
    ["Crafts for material planning"]="Vorgänge für Materialplanung",
    ["Set craft count explicitly; recipe yield is unknown."]="Vorgänge selbst festlegen; Rezeptausbeute unbekannt.",
    ["Need %d · Bags %s · Allocated %s · Missing %s"]="Bedarf %d · Taschen %s · Zugeteilt %s · Fehlt %s",
    ["Marked %d · Still unconfirmed %d · Reserved elsewhere %s"]="Markiert %d · Noch unbestätigt %d · Anders reserviert %s",
    ["Save shopping list"]="Einkaufsliste speichern",
    ["Open shopping lists"]="Einkaufslisten öffnen",
    ["Private shopping list saved."]="Private Einkaufsliste gespeichert.",
    ["Ingredient data is invalid."]="Zutatendaten sind ungültig.",
    ["Material quantities are too large."]="Materialmengen sind zu groß.",
    ["Recipe data is unavailable."]="Rezeptdaten sind nicht verfügbar.",
    ["Craft count must be 1 to 100000."]="Vorgänge müssen zwischen 1 und 100000 liegen.",
    ["Saved material plans use an unsupported version. Data was preserved."]="Materialpläne nutzen eine unbekannte Version. Daten wurden erhalten.",
    ["Order is unavailable."]="Auftrag ist nicht verfügbar.",
    ["This shopping list already belongs to another order."]="Diese Einkaufsliste gehört bereits zu einem anderen Auftrag.",
    ["This order already has a shopping list."]="Dieser Auftrag hat bereits eine Einkaufsliste.",
    ["Shopping list storage is full (100 lists)."]="Einkaufslistenspeicher ist voll (100 Listen).",
    ["This material plan is closed or its order is unavailable."]="Dieser Materialplan ist geschlossen oder sein Auftrag nicht verfügbar.",
    ["Manual amount is invalid."]="Manuelle Menge ist ungültig.",
    ["Old orders use your exact local recipe, if available."]="Alte Aufträge verwenden dein exaktes lokales Rezept, falls vorhanden.",
    ["%d crafts · %s"]="%d Vorgänge · %s",
    ["Private list"]="Private Liste",
    ["Order unavailable"]="Auftrag nicht verfügbar",
    ["Invalid material plans were discarded."]="Ungültige Materialpläne wurden verworfen.",
    ["Private shopping lists (maximum 100)."]="Private Einkaufslisten (maximal 100).",
    ["Select a private shopping list."]="Wähle eine private Einkaufsliste.",
    ["Bags only; oldest active list reserves first."]="Nur Taschen; älteste aktive Liste reserviert zuerst.",
    ["Manual marks do not confirm inventory or handoff."]="Markierungen bestätigen weder Bestand noch Übergabe.",
    ["Materials supplied: "]="Materialien gestellt: ",
    ["Reset acquired mark"]="Beschaffungsmarkierung zurücksetzen",
    ["Mark acquired"]="Als beschafft markieren",
    ["Quantity %d · Unit price %s"]="Menge %d · Stückpreis %s",
    ["Searching community offers…"]="Community-Angebote werden gesucht…",
    ["Community offers; availability is not guaranteed. Click to open."]="Community-Angebote ohne Verfügbarkeitsgarantie. Zum Öffnen klicken.",
    ["Select an ingredient and find offers. No auction house scan."]="Zutat wählen und Angebote suchen. Kein Auktionshaus-Scan.",
    ["Recheck"]="Erneut abgleichen",
    ["Delete list"]="Liste löschen",
    ["Find offers"]="Angebote suchen",
    ["Order sent; shopping list could not be saved: "]="Auftrag gesendet; Einkaufsliste konnte nicht gespeichert werden: ",
    ["This offer is no longer available."]="Dieses Angebot ist nicht mehr verfügbar.",
    ["Ingredient list completeness is unverified."]="Vollständigkeit der Zutatenliste ist nicht bestätigt.",

    ["Today"]="Heute",
    ["What shall we do today?"]="Was machen wir heute?",
    ["No wish"]="Kein Wunsch",
    ["Questing"]="Quests erledigen",
    ["Dungeon"]="Dungeon",["Raid"]="Raid",
    ["Farm materials"]="Materialien farmen",
    ["Level together"]="Zusammen leveln",
    ["Any shared quests"]="Beliebige gemeinsame Quests",
    ["Quest #%d"]="Quest #%d",
    ["Priority %d"]="Priorität %d",
    ["Goal"]="Ziel",
    ["Activity / material (private)"]="Aktivität / Material (privat)",
    ["Duration (minutes)"]="Laufzeit (Minuten)",
    ["End session"]="Sitzung beenden",
    ["Open offer"]="Angebot öffnen",
    ["Session wishes are invalid."]="Sitzungswünsche sind ungültig.",
    ["Choose no more than three wishes."]="Wähle höchstens drei Wünsche.",
    ["Session wish type is invalid."]="Die Wunschkategorie ist ungültig.",
    ["Wish priorities must be distinct: 1 to 3."]="Prioritäten müssen verschieden sein: 1 bis 3.",
    ["Private wish text is too long."]="Der private Wunschtext ist zu lang. Bitte kürzen.",
    ["Quest ID is invalid."]="Die Quest-ID ist ungültig.",
    ["Choose a known activity or use a custom wish."]="Wähle eine bekannte Aktivität oder einen eigenen Wunsch.",
    ["Enter a private activity or material name."]="Gib eine private Aktivität oder einen Materialnamen ein.",
    ["Duplicate wishes are not allowed."]="Identische Wünsche sind nicht erlaubt.",
    ["Saved session wishes use an unsupported version. Data was preserved."]="Die gespeicherten Wünsche haben eine unbekannte Version. Die Daten bleiben erhalten.",
    ["Session duration must be 15 to 480 minutes."]="Die Laufzeit muss 15 bis 480 Minuten betragen.",
    ["Server time is unavailable."]="Die Serverzeit ist nicht verfügbar.",
    ["Shared quest: %s"]="Gemeinsame Quest: %s",
    ["Published group offer: %s"]="Veröffentlichtes Gruppenangebot: %s",
    ["Wish %d: %s"]="Wunsch %d: %s",
    ["Reported available"]="Als verfügbar gemeldet",
    ["Already in your group"]="Bereits in deiner Gruppe",
    ["Session match no longer available."]="Der Sitzungstreffer ist nicht mehr verfügbar.",
    ["Player availability is unknown."]="Die Verfügbarkeit des Spielers ist unbekannt.",
    ["Whisper input is unavailable."]="Die Flüstereingabe ist nicht verfügbar.",
    ["Unsaved changes. Save to update the matches."]="Ungespeicherte Änderungen. Speichern aktualisiert die Treffer.",
    ["Private wishes saved."]="Private Wünsche gespeichert.",
    ["%d private wishes · %d min remaining"]="%d private Wünsche · noch %d Min.",
    ["Session expired. Save explicitly to start again."]="Sitzung abgelaufen. Zum Neustart ausdrücklich speichern.",
    ["No session wishes saved."]="Keine Sitzungswünsche gespeichert.",
    ["Saved session wishes were invalid and could not be restored."]="Ungültige gespeicherte Wünsche konnten nicht wiederhergestellt werden.",
    ["Matching requires addon exchange. Wishes stay private."]="Matching benötigt Addon-Austausch. Die Wünsche bleiben privat.",
    ["%d matching members"]="%d passende Mitglieder",
    ["%d matches · %d contacts left to check"]="%d Treffer · noch %d Kontakte zu prüfen",
    ["No members match your filters. Reset the filters or press Refresh."]="Keine Mitglieder passen zu den Filtern. Setze die Filter zurück oder drücke Aktualisieren.",
    ["No community members found yet. Press Refresh to search again."]="Noch keine Community-Mitglieder gefunden. Drücke Aktualisieren, um erneut zu suchen.",
    ["No open groups match. Change the filters or create your own group under My Group."]="Keine offene Gruppe passt. Ändere die Filter oder erstelle unter Meine Gruppe eine eigene Gruppe.",
    ["You have not applied to a group yet. Open Group Search and press Apply."]="Du hast dich noch bei keiner Gruppe beworben. Öffne Gruppe suchen und drücke Bewerbung senden.",
    ["You follow no activities. Choose a category and activity above and press Follow."]="Du folgst keiner Aktivität. Wähle oben Kategorie und Aktivität und drücke Folgen.",
    ["No applicants yet. They appear here as soon as someone applies to your group."]="Noch keine Bewerber. Sie erscheinen hier, sobald sich jemand bei deiner Gruppe bewirbt.",
    ["No quest requests match. Change the filters or create your own request under My Quest Request."]="Keine Questanfrage passt. Ändere die Filter oder erstelle unter Meine Questanfrage eine eigene Anfrage.",
    ["No quests found. Accept a quest in the game and it appears here."]="Keine Quests gefunden. Nimm im Spiel eine Quest an, dann erscheint sie hier.",
    ["No quest groups yet. They appear when other players share quests that overlap with yours."]="Noch keine Quest-Gruppen. Sie erscheinen, sobald andere Spieler Quests teilen, die sich mit deinen überschneiden.",
    ["You have not offered help yet. Open Quest Requests and press Offer help."]="Du hast noch keine Hilfe angeboten. Öffne Questanfragen und drücke Hilfe anbieten.",
    ["No helpers yet. They appear here as soon as someone offers help."]="Noch keine Helfer. Sie erscheinen hier, sobald jemand Hilfe anbietet.",
    ["No craft requests yet. Search a recipe and press Request crafting."]="Noch keine Herstellungsaufträge. Suche ein Rezept und drücke Herstellung anfragen.",
    ["No shopping lists yet. Open a craft request and press Save shopping list."]="Noch keine Einkaufslisten. Öffne eine Herstellungsanfrage und drücke Einkaufsliste speichern.",
    ["No saved searches. Filter offers under Find Offers and press Save search."]="Keine gespeicherten Suchen. Filtere unter Angebote finden und drücke Suche speichern.",
    ["No updates yet. A saved search alerts you here when a matching offer appears."]="Noch keine Hinweise. Eine gespeicherte Suche meldet sich hier, sobald ein passendes Angebot erscheint.",
    ["Nothing stored locally. Drafts, templates and finished offers appear after you create an offer."]="Nichts lokal gespeichert. Entwürfe, Vorlagen und beendete Angebote erscheinen, sobald du ein Angebot erstellst.",
    ["No events in this period. Widen the period or reset the filters."]="Keine Ereignisse in diesem Zeitraum. Erweitere den Zeitraum oder setze die Filter zurück.",
    ["No matching members. Save a session wish above so players can be matched."]="Keine passenden Mitglieder. Speichere oben einen Sitzungswunsch, damit Spieler zugeordnet werden können.",
    ["Drag to resize the window."]="Ziehen, um die Fenstergröße zu ändern.",
    ["No verified matches in the considered candidates."]="Keine belegten Treffer unter den berücksichtigten Kandidaten.",
    ["Select a member to see the evidence."]="Wähle ein Mitglied für die Begründung.",
    ["Matching uses existing shared quests."]="Matching verwendet vorhandene gemeinsame Quests.",
    ["ZenialCommunity %s or newer reported by two players. Update for new features and bug fixes. Click to dismiss."]="Zwei Spieler melden ZenialCommunity %s oder neuer. Aktualisiere für neue Funktionen und Fehlerbehebungen. Klicken zum Schließen.",
    ["Quest Groups"]="Questgruppen",
    ["%d quests covered; %d shared by everyone."]="%d Quests abgedeckt; %d von allen geteilt.",
    ["%d available · %d in your group · %d unavailable"]="%d verfügbar · %d in deiner Gruppe · %d nicht verfügbar",
    ["%d covered · %d shared by all"]="%d abgedeckt · %d von allen geteilt",
    ["%d shared quests"]="%d gemeinsame Quests",
    ["%d suggestions · %d players considered"]="%d Vorschläge · %d Spieler berücksichtigt",
    ["Select a quest group. Missing quest data is unknown."]="Wähle eine Questgruppe. Fehlende Questdaten sind unbekannt.",
    ["Everyone"]="Alle",
    ["Coverage: at least one fellow player. Shared by all: you and every proposed player. No guarantee of quest completion or reachability. Other party members are not counted."]="Abdeckung: mindestens ein Mitspieler. Von allen geteilt: du und alle vorgeschlagenen Spieler. Keine Garantie für Questabschluss oder Erreichbarkeit. Weitere Gruppenmitglieder sind nicht mitgezählt.",
    ["Enemy targeting and observed stealth alerts with nearby players and local history."]="Gegner-Target- und beobachtete Stealth-Warnungen mit Gegnerliste und lokalem Verlauf.",
    ["Class colors for player nameplates and group level settings."]="Klassenfarben für Spieler-Nameplates und Einstellungen für Gruppenlevel.",
    ["This player is offline."]="Dieser Spieler ist offline.",
    ["Invalid character."]="Ungültiger Charakter.",
    ["This player cannot be reached."]="Spieler ist nicht erreichbar.",
    ["You do not have permission to invite."]="Du hast kein Einladungsrecht.",
    ["Inviting is unavailable."]="Einladen ist nicht verfügbar.",
    ["Inviting is temporarily unavailable."]="Einladen ist momentan nicht verfügbar.",
    ["Invitation failed."]="Einladen fehlgeschlagen.",
    ["The raid is full."]="Der Schlachtzug ist voll.",
    ["The group is full."]="Die Gruppe ist voll.",
    ["Invitation submitted; awaiting response."]="Einladung angefordert; warte auf Antwort.",
    ["Invitation submitted; addon status could not be delivered."]="Einladung angefordert; Addon-Status konnte nicht übertragen werden.",
    ["Press Enter or Search to find community recipes."]="Enter oder Suchen startet die Rezeptsuche in der Community.",
    ["Ingredients per craft"]="Zutaten pro Herstellung",
    ["Search result"]="Suchtreffer",
    ["Ingredient details were not supplied by this crafter."]="Dieser Handwerker hat keine Zutaten übermittelt.",
    ["Item #%d"]="Gegenstand #%d",
    ["Show completed"]="Erledigte anzeigen",
    ["Active"]="Aktiv",["Paused"]="Pausiert",["Draft"]="Entwurf",
    ["Edit offer"]="Angebot bearbeiten",["Open draft"]="Entwurf öffnen",["Relist offer"]="Erneut anbieten",
    ["Delete draft"]="Entwurf löschen",["Delete paused offer"]="Pausiertes Angebot löschen",
    ["Delete archived entry"]="Archiveintrag löschen",["Delete template"]="Vorlage löschen",
    ["The draft no longer exists."]="Dieser Entwurf ist nicht mehr vorhanden.",
    ["Community members"]="Community Mitglieder",
    ["Position less than a minute ago"]="Stand vor weniger als einer Minute",
    ["Position %d min ago"]="Stand vor %d Min.",
    ["New craft request"]="Neue Handwerksanfrage",
    ["Craft request accepted"]="Handwerksanfrage angenommen",
    ["Craft order ready"]="Herstellungsauftrag bereit",
    ["Craft handoff confirmed"]="Übergabe bestätigt",
    ["Craft request declined"]="Handwerksanfrage abgelehnt",
    ["Craft order cancelled"]="Herstellungsauftrag abgebrochen",
    ["Craft request expired"]="Handwerksanfrage abgelaufen",
    ["New matching offer"]="Neues passendes Angebot",
    ["Matching offer updated"]="Passendes Angebot aktualisiert",
    ["Matching offer closed"]="Passendes Angebot beendet",
    ["Application accepted"]="Bewerbung angenommen",
    ["Application declined"]="Bewerbung abgelehnt",
    ["Application withdrawn"]="Bewerbung zurückgezogen",
    ["Group joined"]="Gruppe beigetreten",
    ["A player is coming to help"]="Ein Spieler kommt helfen",
    ["Help commitment withdrawn"]="Hilfszusage zurückgezogen",
    ["New group for a followed activity"]="Neue Gruppe für eine gefolgte Aktivität",
    ["%d unread updates"]="%d ungelesene Meldungen",
    ["%d new updates"]="%d neue Meldungen",
    ["New update"]="Neue Meldung",
    ["Recent trade updates"]="Letzte Handelsmeldungen",
    ["\nClick to open"]="\nKlicken zum Öffnen",
    ["Welcome to ZENIAL Community"]="Willkommen bei ZENIAL Community",
    ["To see members, groups and offers, join ZENIAL Community once."]="Damit du Mitglieder, Gruppen und Angebote siehst, musst du der ZENIAL Community einmalig beitreten.",
    ["Copy the link"]="Link kopieren",
    ["Open the join window"]="Beitrittsfenster öffnen",
    ["Paste and join"]="Einfügen und beitreten",
    ["Click the field and press Ctrl+C."]="Ins Feld klicken, dann Strg+C drücken.",
    ["Press Ctrl+V in the join window and confirm. This window then closes by itself."]="Im Beitrittsfenster Strg+V drücken und bestätigen. Dieses Fenster schließt sich danach von selbst.",
    ["Not joined yet"]="Noch nicht beigetreten",
    ["You are not in ZENIAL Community yet. Join to find members and offers."]="Du bist noch nicht in der ZENIAL Community. Tritt bei, damit du Mitglieder und Angebote findest.",
    ["Join now"]="Jetzt beitreten",
    ["Copy invitation"]="Einladung kopieren",
    ["Select link"]="Link markieren",
    ["Click the link field and press Ctrl+C."]="Linkfeld anklicken und Strg+C drücken.",
    ["Press Ctrl+C. Then open the join window and press Ctrl+V."]="Strg+C drücken. Dann Beitrittsfenster öffnen und Strg+V drücken.",
    ["Paste with Ctrl+V in the join window, then join."]="Im Beitrittsfenster mit Strg+V einfügen und beitreten.",
    ["Open join window"]="Beitrittsfenster öffnen",
    ["Network is not ready yet."]="Netzwerk ist noch nicht bereit.",
    ["Click the text field, then press Ctrl+A and Ctrl+C."]="Textfeld anklicken, dann Strg+A und Strg+C drücken.",
    ["%s: WoW character community, not a Battle.net lounge"]="%s: WoW-Charaktercommunity, keine Battle.net-Lounge",
    ["ZENIAL Community is a WoW character community here. A Battle.net lounge is required."]="ZENIAL Community ist hier eine WoW-Charaktercommunity. Benötigt wird eine Battle.net-Lounge.",
    ["The client's lounge API is unavailable."]="Die Lounge-API des Clients ist nicht verfügbar.",
    ["This client does not allow Battle.net lounges. Copy diagnostics."]="Dieser Client erlaubt keine Battle.net-Lounges. Bitte Diagnose kopieren.",
    ["Addon exchange or character identity is unavailable."]="Austausch ist deaktiviert oder Charakterdaten fehlen.",
    ["The client's region is unavailable. Copy diagnostics."]="Die Region des Clients ist nicht verfügbar. Bitte Diagnose kopieren.",
    ["WoW project data is unavailable. Copy diagnostics."]="Die WoW-Projektkennung fehlt. Bitte Diagnose kopieren.",
    ["Set up Battle.net network"]="Battle.net-Netzwerk einrichten",
    ["Directly reachable"]="Direkt erreichbar",
    ["Reported in network"]="Im Netzwerk gemeldet",
    ["Assigned lounges: %d/%d joined"]="Zugewiesene Lounges: %d/%d beigetreten",
    ["Join the lounge to resolve its ID."]="Lounge beitreten, damit ihre ID erkannt wird.",
    ["No joined Battle.net groups available."]="Keine beigetretene Battle.net-Lounge im Client verfügbar.",
    ["Mode: direct network without channel"]="Modus: Direktes Netzwerk ohne Kanal",
    ["Roster: %d/%d · eligible game accounts: %d"]="Mitgliederliste: %d/%d · passende Spielkonten: %d",
    ["Confirmed: Battle.net %d · addon whisper %d · pending %d"]="Bestätigt: Battle.net %d · Addon-Whisper %d · ausstehend %d",
    ["Group catalog: copy this text or paste the operator's catalog."]="Gruppenkatalog: Text kopieren oder den Betreiberkatalog einfügen.",
    ["Import catalog"]="Katalog importieren",
    ["Group catalog saved."]="Gruppenkatalog gespeichert.",
    ["Copy the invitation links. Confirm the lounge join in Battle.net or WoW."]="Einladungslinks kopieren. Lounge-Beitritt in Battle.net oder WoW bestätigen.",
    ["Ask the operator for an invitation link."]="Betreiber nach einem Einladungslink fragen.",
    ["Battle.net network · 4.0"]="Battle.net-Netzwerk · 4.0",
    ["Set up ZENIAL Community to find members and offers. Public entries are shared; private requests go directly to their owner."]="ZENIAL Community einrichten, um Mitglieder und Angebote zu finden. Öffentliche Einträge werden geteilt; private Anfragen gehen direkt zum Besitzer.",
    ["Invitation links"]="Einladungslinks",
    ["Next group pair"]="Nächstes Gruppenpaar",
    ["Operator: choose a joined Battle.net group and add its invite link."]="Betreiber: Beigetretene Battle.net-Lounge auswählen und Einladungslink hinterlegen.",
    ["Add/update group"]="Gruppe speichern",
    ["Copy/import catalog"]="Katalog kopieren/importieren",
    ["Test Battle.net"]="Battle.net testen",
    ["Refresh groups"]="Gruppen aktualisieren",
    ["Join in WoW"]="In WoW beitreten",
    ["Addon whisper test: full character name (first and last name)"]="Addon-Whisper testen: vollständiger Vor- und Nachname",
    ["Test addon whisper"]="Addon-Whisper testen",
    ["Connection test started."]="Verbindungstest gestartet.",
    ["Open the join dialog after combat."]="Beitrittsfenster nach dem Kampf öffnen.",
    ["Paste the invite in Guilds & Communities > Join Community."]="Einladung unter Gilde & Communitys > Community beitreten einfügen.",
    ["Group setup required"]="Lounge-Beitritt erforderlich",
    ["Battle.net disconnected"]="Battle.net getrennt",
    ["Group roster loading"]="Mitgliederliste lädt",
    ["Scanning group members"]="Gruppenmitglieder werden geprüft",
    ["Group roster ready"]="Mitgliederliste geladen",
    ["No eligible game accounts found yet."]="Noch keine passenden Spielkonten gefunden.",
    ["Character or Battle.net metadata is unavailable."]="Charakter- oder Battle.net-Daten noch nicht verfügbar.",
    ["Enter a full character name."]="Vollständigen Vor- und Nachnamen eingeben.",
    ["A connection test is already pending."]="Ein Verbindungstest läuft bereits.",
    ["Choose another character."]="Anderen Charakter auswählen.",
    ["Game account is not in the selected groups."]="Spielkonto gehört nicht zu den gewählten Gruppen.",
    ["Connection tests are disabled."]="Austausch ist deaktiviert.",
    ["Probe queue is full."]="Verbindungswarteschlange voll.",
    ["Invalid group or invite link."]="Ungültige Gruppe oder ungültiger Einladungslink.",
    ["Join this Battle.net group first."]="Zuerst dieser Battle.net-Lounge beitreten.",
    ["Group catalog is full."]="Gruppenkatalog voll.",
    ["Invalid group catalog."]="Ungültiger Gruppenkatalog.",
    ["At least one group is required."]="Mindestens eine Gruppe ist erforderlich.",
    ["Network records"]="Netzwerkeinträge",
    ["Battle.net network connected"]="Battle.net-Netzwerk verbunden",
    ["Waiting for lounge membership"]="Warte auf Lounge-Beitritt",
    ["No matching players in lounge"]="Keine passenden Spieler in der Lounge",
    ["Diagnostic report"]="Diagnosebericht",["Copy diagnostics"]="Diagnose kopieren",["Select all"]="Alles markieren",
    ["Select all, then Ctrl+C. Refresh updates this snapshot. Escape closes the window."]="Alles markieren, dann Strg+C. Aktualisieren erneuert den Bericht. Escape schließt das Fenster.",
    ["Members"]="Mitglieder",["Crafting"]="Handwerk",["Groups"]="Gruppen",["Quest Help"]="Questhilfe",["Trade"]="Handel",["Profile"]="Profil",["History"]="Historie",["Addon Manager"]="Addon Manager",
    ["Search"]="Suche",["Status"]="Status",["Class"]="Klasse",["Profession"]="Beruf",["Sort"]="Sortierung",["All"]="Alle",["Online"]="Online",["All classes"]="Alle Klassen",["All professions"]="Alle Berufe",["With profile"]="Mit Profil",["Name A–Z"]="Name A–Z",["Level ascending"]="Level aufsteigend",["Level descending"]="Level absteigend",["Last seen"]="Zuletzt gesehen",["Alliance"]="Allianz",["Unknown"]="Unbekannt",["never"]="nie",["just now"]="gerade eben",["You"]="Du",["member"]="Mitglied",["members"]="Mitglieder",["Guild"]="Gilde",["Professions"]="Berufe",["Role"]="Rolle",["Display name"]="Anzeigename",["Level"]="Level",["Version"]="Version",["Current"]="Vorhanden",["Needed"]="Gesucht",["Price"]="Preis",["PREVIEW"]="VORSCHAU",["YOUR CHARACTER"]="DEIN CHARAKTER",
    ["Group Search"]="Gruppe suchen",["My Group"]="Meine Gruppe",["My Applications"]="Meine Bewerbungen",["Follow Activities"]="Aktivitäten folgen",["PvP Help"]="PvP-Hilfe",["Quest Requests"]="Questanfragen",["My Quest Request"]="Meine Questanfrage",["My Help Offers"]="Meine Hilfsangebote",
    ["Browse Offers"]="Angebote finden",["My Offers"]="Meine Angebote",["Character Profile"]="Charakterprofil",["Main & Alts"]="Main & Twinks",["Appearance"]="Darstellung",
    ["Select"]="Auswählen",["Refresh"]="Aktualisieren",["Reset"]="Zurücksetzen",["Reset filters"]="Filter zurücksetzen",["Back"]="Zurück",["← Back to list"]="← Zurück zur Liste",["Cancel"]="Abbrechen",["Delete"]="Löschen",["Edit"]="Bearbeiten",["Whisper"]="Anflüstern",["Invite to group"]="In Gruppe einladen",
    ["Apply"]="Bewerbung senden",["Withdraw"]="Zurückziehen",["Withdraw application"]="Bewerbung zurückziehen",["Accept & invite"]="Annehmen & einladen",["Reject"]="Ablehnen",["Offer help"]="Hilfe anbieten",["Withdraw help offer"]="Hilfsangebot zurückziehen",["Show full history"]="Gesamten Verlauf anzeigen",
    ["Create group"]="Gruppe erstellen",["Publish group"]="Gruppe veröffentlichen",["Create quest request"]="Questanfrage erstellen",["Publish quest request"]="Questanfrage veröffentlichen",["Publish offer"]="Angebot veröffentlichen",["Done / Delete"]="Erledigt / Löschen",["Discard draft"]="Entwurf verwerfen",["Save changes"]="Änderungen speichern",
    ["Category"]="Kategorie",["Activity"]="Aktivität",["Search activity"]="Aktivität suchen",["All categories"]="Alle Kategorien",["All activities"]="Alle Aktivitäten",["Custom activity"]="Eigene Aktivität",["Dungeons"]="Dungeons",["Raids"]="Raids",
    ["Level from"]="Level von",["Level to"]="Level bis",["Target size"]="Zielgröße",["Tank needed"]="Tank gesucht",["Healer needed"]="Heiler gesucht",["Damage needed"]="DD gesucht",["Current group"]="Vorhandene Gruppe",["Note (optional)"]="Notiz (optional)",["Search notes"]="Notiz durchsuchen",["My role"]="Meine Rolle",["Application note (optional)"]="Bewerbungsnotiz (optional)",
    ["No preference"]="Keine Angabe",["Tank"]="Tank",["Healer"]="Heiler",["Damage"]="DD",["Role not assigned"]="Rollen nicht zugewiesen",["Solo"]="Solo",
    ["Applied"]="Beworben",["Invited"]="Eingeladen",["Rejected"]="Abgelehnt",["Joined"]="Beigetreten",["Withdrawn"]="Zurückgezogen",
    ["Select a member."]="Wähle ein Mitglied aus.",["Select a group."]="Wähle eine Gruppe aus.",["Select an application."]="Wähle eine Bewerbung aus.",["Select a quest request."]="Wähle eine Questanfrage aus.",["Select a help offer."]="Wähle ein Hilfsangebot aus.",["Select an offer."]="Wähle ein Angebot aus.",["Select an active PvP help request."]="Wähle einen aktiven PvP-Hilferuf aus.",["Select an entry to view the request timeline."]="Wähle einen Eintrag aus, um den Verlauf der Anfrage zu sehen.",["Select a followed activity on the left."]="Wähle links eine gefolgte Aktivität aus.",
    ["No active group."]="Du hast keine aktive Gruppe.",["No active quest request."]="Du hast keine aktive Questanfrage.",["No active offers."]="Keine aktiven Angebote vorhanden.",["No offers match the filter."]="Keine Angebote entsprechen dem Filter.",["No matching crafters or recipes found."]="Keine passenden Handwerker oder Rezepte gefunden.",["No own professions found."]="Keine eigenen Berufe gefunden.",["Profile not received yet"]="Profil noch nicht empfangen",
    ["Current location"]="Aufenthaltsort",["Current location:"]="Aufenthaltsort:",["Location"]="Ort",["Location:"]="Ort:",["Location unknown"]="Ort unbekannt",["Last known location"]="Letzter bekannter Ort",["Leader location"]="Leader-Ort",["Applicant location"]="Aufenthaltsort des Bewerbers",["Helper location"]="Aufenthaltsort des Helfers",["Leader current location"]="Aufenthaltsort des Leaders",["Quest area"]="Questgebiet",
    ["Incoming applicants"]="Eigene Bewerber",["My helpers"]="Eigene Helfer",["Previous contacts"]="Bisherige Kontakte",["Choose an applicant."]="Wähle einen Bewerber aus.",["Choose a helper."]="Wähle einen Helfer aus.",["No previous contacts stored."]="Noch keine früheren Kontakte gespeichert.",
    ["Remove character"]="Charakter entfernen",["The logged-in character cannot be removed."]="Der eingeloggte Charakter kann nicht entfernt werden.",["Select a character on your server and faction."]="Wähle einen Charakter deines Servers und deiner Fraktion.",
    ["Remove %s from the addon? Its saved profile, professions, recipes and drafts will be removed. History is kept. If it is your main, the logged-in character becomes main."]="%s aus dem Addon entfernen? Gespeichertes Profil, Berufe, Rezepte und Entwürfe werden entfernt. Die Historie bleibt erhalten. Ist dieser Charakter dein Main, wird der eingeloggte Charakter zum Main.",
    ["Profession data is not ready yet."]="Die Berufsdaten sind noch nicht vollständig verfügbar.",["This profession is no longer learned."]="Dieser Beruf ist nicht mehr erlernt.",
    ["Main character"]="Hauptcharakter",["Recorded deaths in the last 60 minutes: %d / 2"]="Erfasste Tode in den letzten 60 Minuten: %d / 2",
    ["The first character is selected as main automatically. Log in with your other characters in the same game world and faction. Other members see your main next to your alt in Members."]="Der erste Charakter wird automatisch als Main festgelegt. Logge dich mit deinen weiteren Charakteren in derselben Spielwelt und Fraktion ein. Andere Mitglieder sehen deinen Main neben deinem Twink unter Mitglieder.",
    ["Player, title or note"]="Spieler, Titel oder Notiz",["Zone"]="Zone",["Level"]="Level",["From quest log"]="Aus dem Questlog",["Manual / level group"]="Manuell / Levelgruppe",["Search quests"]="Quest suchen",["Title / level group"]="Titel / Levelgruppe",["Zone (optional)"]="Zone (optional)",["Duration in minutes"]="Ablauf in Minuten",["Message (optional)"]="Nachricht (optional)",
    ["Item, service or player"]="Gegenstand, Dienstleistung oder Spieler",["Type"]="Art",["Sell"]="Verkaufen",["Buy"]="Kaufen",["Service"]="Dienstleistung",["Wanted"]="Suche",["For sale"]="Verkaufe",["Item or service"]="Gegenstand oder Dienstleistung",["Quantity"]="Menge",["Total price gold"]="Gesamtpreis Gold",["Silver"]="Silber",["Copper"]="Kupfer",["Duration in minutes (max. 1440)"]="Ablauf in Minuten (max. 1440)",["offer"]="Angebot",["offers"]="Angebote",
    ["All item categories"]="Alle Gegenstandskategorien",["Weapons"]="Waffen",["Armor"]="Rüstung",["Bags"]="Taschen",["Consumables"]="Verbrauchsgüter",["Materials"]="Materialien",["Ammunition"]="Munition",["Recipes"]="Rezepte",["Quest items"]="Questgegenstände",["Miscellaneous"]="Sonstiges",["Unclassified"]="Nicht zugeordnet",["Unit price"]="Stückpreis",["Total price"]="Gesamtpreis",["Minimum unit price (gold)"]="Stückpreis min. (Gold)",["Maximum unit price (gold)"]="Stückpreis max. (Gold)",["Name"]="Name",["Unit price ascending"]="Stückpreis aufsteigend",["Unit price descending"]="Stückpreis absteigend",["Ending soon"]="Endet bald",["Invalid price filter"]="Ungültiger Preisfilter",
    ["Display name (optional)"]="Anzeigename (optional)",["Preferred role"]="Bevorzugte Rolle",["Save profile"]="Profil speichern",["Show profile in Members"]="Profil bei Mitglieder zeigen",["Set as main character"]="Als Hauptcharakter festlegen",["Default size"]="Standardgröße",["Reset position"]="Position zurücksetzen",
    ["Period"]="Zeitraum",["Last 7 days"]="Letzte 7 Tage",["Last 30 days"]="Letzte 30 Tage",["Last 90 days"]="Letzte 90 Tage",["Area"]="Bereich",["All areas"]="Alle Bereiche",["Own character"]="Eigener Charakter",["All characters"]="Alle Charaktere",["Player or content"]="Spieler oder Inhalt",["Delete player history"]="Spieler-Historie löschen",["Delete history"]="Historie löschen",
    ["Choose activities you want to be notified about when a new group is published."]="Wähle Aktivitäten aus, bei deren neu veröffentlichten Gruppen du benachrichtigt werden möchtest.",["Follow"]="Folgen",["Stop following"]="Nicht mehr folgen",
    ["Receive PvP help requests"]="PvP-Hilferufe empfangen",["Area filter"]="Gebietsfilter",["All zones"]="Alle Gebiete",["Only my current zone"]="Nur meine aktuelle Zone",["I'm coming"]="Ich komme",["Show on map"]="Auf Karte zeigen",["Set waypoint"]="Wegpunkt setzen",["Block"]="Blockieren",["I'm being ganked. HELP!"]="Werde gegankt. HILFE!",["Update location"]="Standort aktualisieren",["Done"]="Erledigt",["Helpers committed"]="Helfer zugesagt",["Invite"]="Einladen",["Who is attacking you? Number and level (optional, e.g. 3 × level 60)"]="Wer greift dich an? Anzahl und Level (optional, z. B. 3× Level 60)",["Share targeted enemy details"]="Angaben zum anvisierten Gegner mitsenden",["I am being attacked by players"]="Ich werde von Spielern angegriffen",["Call for help"]="Hilfe rufen",
    ["My professions"]="Meine Berufe",["MY PROFESSIONS"]="MEINE BERUFE",["MAIN AND ALTS"]="MAIN UND TWINKS",["APPEARANCE"]="DARSTELLUNG",["Scan professions"]="Berufe scannen",["Scan recipes"]="Rezepte scannen",["Recipe, item or profession"]="Rezept, Gegenstand oder Beruf",["Search for a profession, recipe or item."]="Suche nach einem Beruf, Rezept oder Gegenstand.",
    ["Community tools for Azeroth"]="Community-Werkzeuge für Azeroth",["WoW Forever Discord"]="WoW Forever Discord",
    ["Crit and last-hit effects with graphics, sound and a freely selectable position."]="Krit- und Last-Hit-Effekte mit Grafik, Klang und frei wählbarer Position.",["Local gunfire and reload sounds with random or fixed selection."]="Lokale Gewehr- und Nachladeklänge mit Zufalls- oder Festwahl.",["Local event and API capture for addon development."]="Lokaler Event- und API-Mitschnitt für die Addon-Entwicklung.",["Embedded interface could not be created."]="Eingebettete Oberfläche konnte nicht erstellt werden.",
    ["Installed and loaded"]="Installiert und geladen",["Not installed"]="Nicht installiert",["Installed but disabled"]="Installiert, aber deaktiviert",["Loading"]="Wird geladen",["Not loadable"]="Nicht ladbar",["Installed · available after /reload"]="Installiert · nach /reload verfügbar",["Installed · embedding update required"]="Installiert · Update für Einbettung erforderlich",["Open addon window"]="Addonfenster öffnen",["Enable in AddOns menu"]="Im Addonmenü aktivieren",["/reload required"]="/reload erforderlich",
    ["Application sent."]="Bewerbung gesendet.",["Application withdrawn."]="Bewerbung zurückgezogen.",["Help offer sent."]="Hilfeangebot gesendet.",["Help offer withdrawn."]="Hilfeangebot zurückgezogen.",["Invitation sent."]="Einladung gesendet.",["Invite sent."]="Einladung versendet.",["Profile saved."]="Profil gespeichert.",["Offer saved."]="Angebot gespeichert.",["Location updated."]="Standort aktualisiert.",["Help request ended."]="Hilferuf beendet.",["Help request is being sent."]="Hilferuf wird versendet.",["Commitment sent."]="Zusage gesendet.",["Commitment withdrawn."]="Zusage zurückgezogen.",["Waypoint set."]="Wegpunkt gesetzt.",
    ["The group is no longer active."]="Die Gruppe ist nicht mehr aktiv.",["The quest request is no longer active."]="Die Questanfrage ist nicht mehr aktiv.",["You already applied."]="Du hast dich bereits beworben.",["You already offered help."]="Du hast bereits Hilfe angeboten.",["No active application."]="Keine aktive Bewerbung.",["No active help offer."]="Kein aktives Hilfeangebot.",["Application is no longer active."]="Bewerbung nicht mehr aktiv.",["Help offer is no longer active."]="Hilfsangebot nicht mehr aktiv.",["Invalid role."]="Ungültige Rolle.",["Exchange unavailable."]="Austausch nicht verfügbar.",["Same realm only."]="Nur derselbe Realm.",["Queue full."]="Warteschlange voll.",["Data is invalid or too large."]="Daten sind ungültig oder zu groß.",
    ["Please enter a valid activity."]="Bitte eine gültige Aktivität angeben.",["Please enter a title or level group."]="Bitte einen Titel oder eine Levelgruppe angeben.",["Please enter an item or service."]="Bitte einen Gegenstand oder eine Dienstleistung angeben.",["Input is too long."]="Eingabe ist zu lang.",["Item not found."]="Gegenstand nicht gefunden.",["The target size has already been reached."]="Die Zielgröße ist bereits erreicht.",["Confirm first that players are attacking you."]="Bestätige zuerst, dass Spieler dich angreifen.",
    ["Group published"]="Gruppe veröffentlicht",["Group updated"]="Gruppe aktualisiert",["Group closed"]="Gruppe geschlossen",["Group expired"]="Gruppe abgelaufen",["Quest request created"]="Questanfrage erstellt",["Quest request updated"]="Questanfrage geändert",["Quest request closed"]="Questanfrage geschlossen",["Quest request expired"]="Questanfrage abgelaufen",
    ["Application received"]="Bewerbung erhalten",["Application queued"]="Versand vorgemerkt",["Application delivered"]="Versand bestätigt",["Application failed"]="Versand fehlgeschlagen",["Application withdrawn"]="Bewerbung zurückgezogen",["Withdrawal received"]="Rücknahme erhalten",["Invitation sent"]="Einladung gesendet",["Invitation received"]="Einladung erhalten",["Rejection sent"]="Ablehnung gesendet",["Rejection received"]="Ablehnung erhalten",["Observed together in group"]="Gemeinsam in Gruppe beobachtet",["Delivery pending"]="Versand vorgemerkt",["Transport confirmed"]="Transport bestätigt",["Delivery failed"]="Versand fehlgeschlagen",["Status transfer unknown"]="Statusübertragung unbekannt",["Area unknown"]="Gebiet unbekannt",
}

local ACTIVITY_DE={
    ["Open World PvP"]="Open-World-PvP",["Warsong Gulch"]="Kriegshymnenschlucht",["Arathi Basin"]="Arathibecken",["Alterac Valley"]="Alteractal",
    ["Hall of Thanes"]="Halle der Thanen",["Ruins of Lordaeron"]="Ruinen von Lordaeron",["Excavation Site"]="Ausgrabungsstätte",["City of Dalaran"]="Stadt Dalaran",["The Drowned City"]="Die versunkene Stadt",["Alcaz Prison"]="Gefängnis von Alcaz",["Blackmaw Hold"]="Schwarzschlundfeste",["Shaper's Terrace"]="Terrasse des Formers",
    ["Ragefire Chasm"]="Ragefireabgrund",["Wailing Caverns"]="Höhlen des Wehklagens",["The Deadmines"]="Die Todesminen",["Shadowfang Keep"]="Burg Schattenfang",["Blackfathom Deeps"]="Tiefschwarze Grotte",["The Stockade"]="Das Verlies",["Razorfen Kraul"]="Kral der Klingenhauer",
    ["Scarlet Monastery: Graveyard"]="Scharlachrotes Kloster: Friedhof",["Scarlet Monastery: Library"]="Scharlachrotes Kloster: Bibliothek",["Scarlet Monastery: Armory"]="Scharlachrotes Kloster: Waffenkammer",["Scarlet Monastery: Cathedral"]="Scharlachrotes Kloster: Kathedrale",["Razorfen Downs"]="Hügel der Klingenhauer",
    ["Sunken Temple"]="Der Versunkene Tempel",["Blackrock Depths"]="Blackrocktiefen",["Dire Maul East"]="Düsterbruch: Ost",["Dire Maul North"]="Düsterbruch: Nord",["Dire Maul West"]="Düsterbruch: West",["Lower Blackrock Spire"]="Untere Schwarzfelsspitze",["Stratholme: Main Gate"]="Stratholme: Haupteingang",["Stratholme: Service Gate"]="Stratholme: Dienstboteneingang",["Upper Blackrock Spire"]="Obere Schwarzfelsspitze",
    ["Deepgrove Tomb"]="Tiefengrabhügel",["Mount Hyjal Summit"]="Hyjalgipfel",["Onyxia's Lair"]="Onyxias Hort",["Molten Core"]="Geschmolzener Kern",["Blackwing Lair"]="Pechschwingenhort",["Ruins of Ahn'Qiraj"]="Ruinen von Ahn'Qiraj",["Temple of Ahn'Qiraj"]="Tempel von Ahn'Qiraj"
}

local EXTRA_DE={
    ["Favorites"]="Favoriten",["Craft orders"]="Herstellungsaufträge",["Connection"]="Verbindung",["Management"]="Verwaltung",["Search alerts"]="Suchalarme",
    ["Save search"]="Suche speichern",["Pause"]="Pausieren",["Duplicate"]="Duplizieren",["Completed"]="Erledigt",["Open / relist"]="Öffnen / erneut anbieten",
    ["Save as template"]="Als Vorlage speichern",["Delete locally"]="Lokal löschen",["Save as local draft"]="Als lokalen Entwurf speichern",
    ["My level matches"]="Mein Level passt",["My role is needed"]="Meine Rolle wird gesucht",["Available leaders only"]="Nur verfügbare Leiter",["Choose a preferred role in your profile to use the role filter."]="Wähle im Profil eine bevorzugte Rolle, um den Rollenfilter zu verwenden.",
    ["Template"]="Vorlage",["Use template"]="Vorlage verwenden",["Request crafting"]="Herstellung anfragen",["Check again now"]="Jetzt erneut prüfen",
    ["Create group or template"]="Gruppe oder Vorlage erstellen",["Manage templates"]="Vorlagen verwalten",["Choose template"]="Vorlage wählen",["Delete template"]="Vorlage löschen",
    ["New templates are created in the group form. Templates remain local and do not publish a group."]="Neue Vorlagen erstellst du im Gruppenformular. Vorlagen bleiben lokal und veröffentlichen keine Gruppe.",
    ["Template name"]="Vorlagenname",["Duration (min.)"]="Laufzeit (Min.)",["Save template"]="Vorlage speichern",["Saves locally without publishing the group."]="Speichert lokal, ohne die Gruppe zu veröffentlichen.",
    ["Choose a template first."]="Wähle zuerst eine Vorlage.",["Group template deleted."]="Gruppenvorlage gelöscht.",["Check the template name and save it below."]="Vorlagenname prüfen und unten speichern.",
    ["Please enter a template name."]="Bitte einen Vorlagennamen angeben.",["The duration must be between 1 and 1440 minutes."]="Die Laufzeit muss zwischen 1 und 1440 Minuten liegen.",["Group template saved. It was not published."]="Gruppenvorlage gespeichert. Sie wurde nicht veröffentlicht.",
    ["Template is invalid."]="Vorlage ist ungültig.",["A maximum of 20 group templates is allowed."]="Maximal 20 Gruppenvorlagen.",
    ["Private note"]="Private Notiz",["Save note"]="Notiz speichern",["Favorite"]="Favorit",["Search"]="Suchen",
    ["Connected – no other players confirmed yet"]="Verbunden – noch keine anderen Spieler bestätigt",
    ["Loading data"]="Daten werden nachgeladen",["Transmission throttled"]="Übertragung gedrosselt",["Older addon version detected"]="Ältere Addonversion erkannt",["Connected"]="Verbunden",
    ["Channel"]="Kanal",["participants"]="Teilnehmer",["Confirmed reachable"]="Bestätigt erreichbar",["older version"]="alte Version",["Queue"]="Warteschlange",["Inbound"]="Eingang",["fragments"]="Fragmente",["Last received"]="Letzter Empfang",["Last error"]="Letzter Fehler",["Recipe search"]="Rezeptsuche",["checked"]="geprüft",["matches"]="Treffer",
}
for english,deutsch in pairs(EXTRA_DE)do DE[english]=deutsch end

-- Additional runtime labels and format strings for the 3.1 workflows.
DE["First Aid"]="Erste Hilfe"
DE["Blacksmithing"]="Schmiedekunst"
DE["Leatherworking"]="Lederverarbeitung"
DE["Alchemy"]="Alchemie"
DE["Herbalism"]="Kräuterkunde"
DE["Cooking"]="Kochkunst"
DE["Mining"]="Bergbau"
DE["Tailoring"]="Schneiderei"
DE["Engineering"]="Ingenieurskunst"
DE["Enchanting"]="Verzauberkunst"
DE["Fishing"]="Angeln"
DE["Skinning"]="Kürschnerei"
DE["Jewelcrafting"]="Juwelenschleifen"
DE["Inscription"]="Inschriftenkunde"
DE["Enable community connection"]="Community-Verbindung aktivieren"
DE["Automatic member discovery"]="Mitglieder automatisch erkennen"
DE["Visible profile"]="Profil sichtbar machen"
DE["Share professions and recipes"]="Berufe und Rezepte teilen"
DE["Share guild"]="Gilde teilen"
DE["Request from %s: %s"]="Anfrage an %s: %s"
DE["Select the note's member before saving."]="Wähle den Charakter der Notiz vor dem Speichern aus."
DE["Private note saved."]="Private Notiz gespeichert."
DE["Broadcast queued"]="Versand vorgemerkt"
DE["Broadcast sent"]="Hilferuf gesendet"
DE["Broadcast failed"]="Versand fehlgeschlagen"
DE["Waiting to broadcast"]="Warte auf Versand"
DE["ACTIVE PVP HELP REQUEST"]="AKTIVER PVP-HILFERUF"
DE["%d minutes remaining · %s · %d volunteers"]="Noch %d Minuten · %s · %d Zusagen"
DE["Delivery to individual helpers is unknown until they respond."]="Der Empfang einzelner Helfer ist erst durch ihre Antwort bekannt."
DE[" followed activities"]=" Aktivitäten gefolgt"
DE[" orders"]=" Aufträge"
DE[" professions"]=" Berufen"
DE[" events"]=" Ereignisse"
DE[" results"]=" Ergebnisse"
DE[" history entries deleted."]=" Historieneinträge gelöscht."
DE[" minutes"]=" Minuten"
DE[" recipes"]=" Rezepte"
DE[" recipes from "]=" Rezepte aus "
DE[" items\nStatus: "]=" Stück\nStatus: "
DE[" matches"]=" Treffer"
DE[" needs PvP help\n"]=" braucht PvP-Hilfe\n"
DE[" needs PvP help|r"]=" braucht PvP-Hilfe|r"
DE[" is received."]=" empfangen wird."
DE[" checked · "]=" geprüft · "
DE[" saved searches"]=" gespeicherte Suchen"
DE[" is invalid."]=" ist ungültig."
DE[" local entries"]=" lokale Einträge"
DE[" new groups for followed activities\nClick to open"]=" neue Gruppen für gefolgte Aktivitäten\nKlicken zum Öffnen"
DE[" new PvP help requests\nClick to open"]=" neue PvP-Hilferufe\nKlicken zum Öffnen"
DE[" new trade match"]=" neuer Handelstreffer"
DE[" open groups"]=" offene Gruppen"
DE[" no response"]=" ohne Antwort"
DE[" really delete?"]=" wirklich löschen?"
DE[" · Click to open"]=" · Klicken zum Öffnen"
DE[" · Materials: "]=" · Materialien: "
DE[" · Tip: "]=" · Trinkgeld: "
DE[" · complete"]=" · abgeschlossen"
DE[" · running"]=" · läuft"
DE[" · Delivery: "]=" · Übertragung: "
DE["0 followed activities"]="0 Aktivitäten gefolgt"
DE["0 orders"]="0 Aufträge"
DE["0 professions"]="0 Berufen"
DE["0 results"]="0 Ergebnisse"
DE["0 saved searches"]="0 gespeicherte Suchen"
DE["0 local entries"]="0 lokale Einträge"
DE["0 open groups"]="0 offene Gruppen"
DE["1 event"]="1 Ereignis"
DE["1 result"]="1 Ergebnis"
DE["1 open group"]="1 offene Gruppe"
DE["Choose an activity"]="Aktivität wählen"
DE["All history entries for "]="Alle Historieneinträge zu "
DE["Send request"]="Anfrage senden"
DE["Offer template saved."]="Angebotsvorlage gespeichert."
DE["Accepted"]="Angenommen"
DE["Only characters in your current game world and faction are shown and linked."]="Angezeigt und verknüpft werden nur Charaktere deiner aktuellen Spielwelt und Fraktion."
DE["Location\nSelect an applicant."]="Aufenthaltsort\nWähle einen Bewerber aus."
DE["Location\nSelect a helper."]="Aufenthaltsort\nWähle einen Helfer aus."
DE["Order updated."]="Auftrag aktualisiert."
DE["Outgoing"]="Ausgang"
DE["Incoming"]="Eingang"
DE["Targeted enemy at death: "]="Beim Tod anvisierter Gegner: "
DE["No readable enemy player was targeted when you died."]="Beim Tod war kein lesbarer gegnerischer Spieler anvisiert."
DE["Ready"]="Bereit"
DE["Previous contacts\nNo previous contacts saved."]="Bisherige Kontakte\nNoch keine früheren Kontakte gespeichert."
DE["Previous contacts\nSelect an applicant."]="Bisherige Kontakte\nWähle einen Bewerber aus."
DE["The price is invalid."]="Der Preis ist ungültig."
DE["The automatic scan waits for your own open profession window."]="Der automatische Scan wartet auf ein eigenes geöffnetes Berufsfenster."
DE["The duration must be between 1 and 120 minutes."]="Die Laufzeit muss zwischen 1 und 120 Minuten liegen."
DE["The quantity is invalid."]="Die Menge ist ungültig."
DE["Really delete the entire finder history?"]="Die gesamte Finder-Historie wirklich löschen?"
DE["The requested roles exceed the target group size."]="Die gesuchten Rollen überschreiten die Zielgröße."
DE["You will be notified when a new group for "]="Du erhältst einen Hinweis, wenn eine neue Gruppe für "
DE["You follow "]="Du folgst "
DE["You now follow "]="Du folgst jetzt "
DE["You can now prepare a PvP help request."]="Du kannst jetzt einen PvP-Hilferuf vorbereiten."
DE["Invitation sent; addon status could not be delivered."]="Einladung gesendet; Addon-Status konnte nicht übertragen werden."
DE["Recorded professions: "]="Erfasste Berufe: "
DE["Window size and the last section are saved per installation. Your existing position and scale settings are retained."]="Fenstergröße und letzter Bereich werden pro Installation gespeichert. Die Position und Skalierung bleiben mit deinen bisherigen Einstellungen kompatibel."
DE["Yesterday, "]="Gestern, "
DE["Requested quantity"]="Gewünschte Stückzahl"
DE["Group"]="Gruppe"
DE["Today, "]="Heute, "
DE["Help request unavailable."]="Hilferuf nicht verfügbar."
DE["No player"]="Kein Spieler"
DE["No crafters match the filters."]="Keine Handwerker entsprechen den Filtern."
DE["Loading recipes … "]="Lade Rezepte … "
DE["Maximum level is invalid."]="Level bis ist ungültig."
DE["Minimum level is invalid."]="Level von ist ungültig."
DE["Local draft saved."]="Lokaler Entwurf gespeichert."
DE["Materials provided"]="Materialien werden gestellt"
DE["New group: "]="Neue Gruppe: "
DE["Group no longer available"]="Nicht mehr verfügbare Gruppe"
DE["Quest request no longer available"]="Nicht mehr verfügbare Questanfrage"
DE["REQUEST PVP HELP"]="PVP-HILFE RUFEN"
DE["Price filter is invalid."]="Preisfilter ist ungültig."
DE["PvP help active"]="PvP-Hilfe aktiv"
DE["Requesting recipes …"]="Rezepte werden angefragt …"
DE["Player"]="Spieler"
DE["Quantity or tip is invalid."]="Stückzahl oder Trinkgeld ist ungültig."
DE["Search alert saved."]="Suchalarm gespeichert."
DE["Delete search alert"]="Suchalarm löschen"
DE["Tip in gold"]="Trinkgeld in Gold"
DE["Being ganked. HELP!\nClick to review"]="Werde gegankt. HILFE!\nKlicken zum Prüfen"
DE["Select a saved search."]="Wähle eine gespeicherte Suche aus."
DE["Select a profession or recipe result."]="Wähle einen Beruf oder einen Rezepttreffer aus."
DE["Select an entry."]="Wähle einen Eintrag aus."
DE["Select a crafting order."]="Wähle einen Herstellungsauftrag aus."
DE["Target size: "]="Zielgröße: "
DE["Volunteer offer withdrawn"]="Zusage zurückgezogen"
DE["Withdraw offer to help"]="Zusage zurückziehen"
DE["\nTargeted enemy at death: "]="\nBeim Tod anvisierter Gegner: "
DE["\nYour offer to help was sent."]="\nDeine Zusage wurde gesendet."
DE["\nRequesting details from the sender …"]="\nDetails werden beim Absender angefragt …"
DE["\nThis player can craft the requested recipe."]="\nDieser Spieler kann das gesuchte Rezept herstellen."
DE["\nClick to open"]="\nKlicken zum Öffnen"
DE["\nLast recipe scan: "]="\nLetzter Rezeptscan: "
DE["\nTime remaining: "]="\nLäuft noch "
DE["\nMaterials: "]="\nMaterialien: "
DE["\nRecipe catalog: "]="\nRezeptkatalog: "
DE["\nSelect a recipe on the right."]="\nWähle rechts ein Rezept aus."
DE["\nremaining "]="\nnoch "
DE["new applications and offers to help"]="neue Bewerbungen und Hilfsangebote"
DE["new group application"]="neue Gruppenbewerbung"
DE["new group applications"]="neue Gruppenbewerbungen"
DE["new offers to help"]="neue Hilfsangebote"
DE["new offer to help"]="neues Hilfsangebot"
DE["not run yet"]="noch nicht ausgeführt"
DE["provided"]="werden gestellt"
DE["not provided"]="nicht gestellt"
DE["|cffff5555SCAN NOT RUN|r\n"]="|cffff5555SCAN NICHT AUSGEFÜHRT|r\n"
DE["|cffff5555IMPORTANT: OPEN THE CORRECT PROFESSION WINDOW|r"]="|cffff5555WICHTIG: DAS PASSENDE BERUFSFENSTER MUSS GEÖFFNET SEIN|r"
DE["|cffffd36bREQUEST CRAFTING|r"]="|cffffd36bHERSTELLUNG ANFRAGEN|r"
DE["|cffffd36bMAIN AND ALTS|r"]="|cffffd36bMAIN UND TWINKS|r"
DE["|r\nNew matching offers, changes and closures trigger a local alert. Existing results after login remain quiet."]="|r\nNeue passende Angebote, Änderungen und Schließungen erzeugen einen lokalen Hinweis. Bestehende Treffer nach Login bleiben still."
DE["|r\nRecipe in the catalog of "]="|r\nRezept im Katalog von "
DE["|r\nStatus: "]="|r\nStatus: "
DE["Open your own profession window and keep the recipe list visible. ZenialCommunity scans automatically. If a complete unfiltered list is not safely available, found recipes are only added and the previous complete catalog is preserved."]="Öffne dein eigenes WoW-Berufsfenster und lasse die Rezeptliste sichtbar. ZenialCommunity scannt dann automatisch. Ist die vollständige ungefilterte Liste nicht sicher verfügbar, werden erkannte Rezepte nur ergänzt und nichts aus dem letzten vollständigen Stand gelöscht."
DE["Confirm handoff"]="Übergabe bestätigen"
DE["Handoff confirmed"]="Übergabe bestätigt"
DE["Another %d death(s) needed before requesting help."]="Noch %d Tod/Tode bis zum Hilferuf."
DE["%d recipes found for %s."]="%d Rezepte für %s erkannt."
DE["Complete: %s"]="Vollständig: %s"
DE["Partial scan: %s"]="Teilscan: %s"
DE["Expand your skill categories to update professions safely."]="Klappe deine Fertigkeitskategorien auf, damit die Berufe sicher aktualisiert werden können."
DE["Own profession data is not ready yet."]="Eigene Berufsdaten sind noch nicht verfügbar."
DE["Ctrl+C to copy"]="Strg+C zum Kopieren"
DE["Click to open"]="Klicken: Öffnen"
DE["Attackers"]="Angreifer"
DE["Place of death"]="Todesort"
DE["Help request less than a minute ago"]="Hilferuf vor weniger als einer Minute"
DE["Help request %d min ago"]="Hilferuf vor %d Min."
DE["PvP help needed"]="PvP-Hilfe gesucht"
DE[" needs PvP help"]=" braucht PvP-Hilfe"
DE["Right-click: options"]="Rechtsklick: Optionen"
DE["Open ZENIAL Community"]="ZENIAL Community öffnen"
DE["Hide minimap button"]="Minimap-Schaltfläche ausblenden"
DE["Minimap button hidden. Bring it back with /zenial minimap."]="Minimap-Schaltfläche ausgeblendet. Mit /zenial minimap wieder einblenden."
DE["Minimap button shown."]="Minimap-Schaltfläche eingeblendet."
DE["Window: 1060 × 690 default · minimum 900 × 610"]="Fenster: 1060 × 690 Standard · mindestens 900 × 610"
DE["Incoming applicants (0)"]="Eigene Bewerber (0)"
DE["My helpers (0)"]="Eigene Helfer (0)"
DE["Volunteers (0)"]="Helfer zugesagt (0)"
DE["Volunteers (%d)"]="Helfer zugesagt (%d)"
DE["0 applications"]="0 Bewerbungen"
DE["1 application"]="1 Bewerbung"
DE[" applications"]=" Bewerbungen"
DE["0 offers to help"]="0 Hilfsangebote"
DE["1 offer to help"]="1 Hilfsangebot"
DE[" offers to help"]=" Hilfsangebote"
DE["Coming to help"]="Kommt helfen"
DE[" · your own entry"]=" · dein eigener Eintrag"
DE["Saved search"]="Gespeicherte Suche"
DE["All offers"]="Alle Angebote"
DE["Required safety APIs are unavailable."]="Erforderliche Sicherheits-APIs sind nicht verfügbar."
DE["Good tank"]="Guter Tank"
DE["Good healer"]="Guter Heiler"
DE["Enchanter"]="Verzauberer"
DE["Leveling partner"]="Levelpartner"
DE["Reliable player"]="Zuverlässiger Mitspieler"
DE["Private categories"]="Private Kategorien"
DE["Private category"]="Private Kategorie"
DE["Contact"]="Kontakt"
DE["Close"]="Schließen"
DE["Activities"]="Aktivitäten"
DE["Settings"]="Einstellungen"
DE["When"]="Wann"
DE["Now"]="Jetzt"
DE["Later"]="Später"
DE["Planned"]="Geplant"
DE["Any time"]="Jeder Zeitpunkt"
DE["Organized by me"]="Von mir organisiert"
DE["My applications"]="Meine Anmeldungen"
DE["Matches your wish: %s"]="Passt zu deinem Wunsch: %s"
DE["Outside your session time budget"]="Außerhalb deines Zeitbudgets"
DE["Saved activity"]="Gespeicherte Aktivität"
DE["Saved application"]="Gespeicherte Anmeldung"
DE["This activity is no longer available."]="Diese Aktivität ist nicht mehr verfügbar."
DE["%d activities · page %d/%d"]="%d Aktivitäten · Seite %d/%d"
DE["Select an activity. Open its details to apply or manage it."]="Wähle eine Aktivität. Öffne ihre Details zum Anmelden oder Verwalten."
DE["No matching activities received."]="Keine passenden Aktivitäten empfangen."
DE["Now for you"]="Jetzt passend"
DE["Planned today"]="Heute geplant"
DE["Your activities today"]="Deine Aktivitäten heute"
DE["Matching fellow players"]="Passende Mitspieler"
DE["Choose what you want to do; your wishes stay private."]="Wähle, worauf du Lust hast. Deine Wünsche bleiben privat."
DE["Edit private wishes"]="Private Wünsche bearbeiten"
DE["Create activity"]="Aktivität erstellen"
DE["Open activity"]="Aktivität öffnen"
DE["Enter an activity."]="Gib eine Aktivität ein."
DE["Choose now or planned. Review the details before publishing."]="Wähle jetzt oder geplant. Prüfe die Details vor dem Veröffentlichen."
DE["Back to activities"]="Zurück zu Aktivitäten"
DE["Back to today"]="Zurück zu Heute"
DE["Character profile"]="Charakterprofil"
DE["Main & alts"]="Main und Twinks"
DE["Display settings"]="Darstellung"
DE["Connection and privacy"]="Verbindung und Datenschutz"
DE["Contact history"]="Kontaktverlauf"
DE["All shopping lists"]="Alle Materiallisten"
DE["Back to orders"]="Zurück zu Aufträgen"
DE["Shared quests"]="Gemeinsame Quests"
DE["Quest groups"]="Questgruppen"
DE["Follow activities"]="Gemerkte Aktivitäten"
DE["Continue"]="Weiter"
DE["Archive"]="Archiv"
DE["Group details"]="Gruppendetails"
DE["More matches are available under Activities."]="Weitere Treffer findest du unter Aktivitäten."
DE["All private categories"]="Alle privaten Kategorien"
DE["Recontact suggestions"]="Wiederkontakt-Vorschläge"
DE["Your private categories:"]="Deine privaten Kategorien:"
DE["Previously observed together in a group."]="Bereits gemeinsam in einer Gruppe beobachtet."
DE["Last together %d days ago."]="Zuletzt gemeinsam vor %d Tagen."
DE["Select a contact to mark. Categories stay private."]="Wähle einen Kontakt zum Markieren. Kategorien bleiben privat."
DE["Offer marking after observed groups"]="Markierung nach beobachteten Gruppen anbieten"
DE["Private categories use a newer format."]="Private Kategorien verwenden ein neueres Format."
DE["Invalid private category."]="Ungültige private Kategorie."
DE["Select an unblocked contact."]="Wähle einen nicht blockierten Kontakt."
DE["Maximum 1,000 categorized contacts."]="Maximal 1.000 kategorisierte Kontakte."
DE["Contact storage is full."]="Kontaktspeicher ist voll."
DE["Matches wish %d"]="Passend zu Wunsch %d"
DE["Wish %d · %s"]="Wunsch %d · %s"
DE["No wishes chosen"]="Noch keine Wünsche"
DE["No active wishes"]="Keine aktiven Wünsche"
DE["Your wishes for today · private"]="Deine Wünsche für heute · privat"
DE["Choose up to three private wishes. Matching activities and players appear below."]="Wähle bis zu drei private Wünsche. Passende Aktivitäten und Mitspieler erscheinen darunter."
DE["%d private wishes for today"]="%d private Wünsche für heute"
DE["Save wishes"]="Wünsche speichern"
DE["Clear wishes"]="Wünsche löschen"
DE["Show Addon Manager in the left navigation"]="Addon Manager in der linken Navigation anzeigen"
DE["Whisper is unavailable."]="Anflüstern ist momentan nicht verfügbar."
DE["Organizer: %s"]="Ersteller: %s"
DE["Organized by you"]="Von dir organisiert"
DE["Your application: pending"]="Deine Bewerbung: offen"
DE["Application pending delivery"]="Deine Bewerbung wird übermittelt"
DE["Withdrawal pending"]="Rücknahme wird übermittelt"
DE["You were invited"]="Du wurdest eingeladen"
DE["You are in the group"]="Du bist in der Gruppe"
DE["Your attendance is confirmed"]="Deine Teilnahme ist bestätigt"
DE["You are on the waitlist"]="Du stehst auf der Ersatzbank"
DE["Your application was declined"]="Deine Bewerbung wurde abgelehnt"
DE["Application withdrawn"]="Bewerbung zurückgezogen"
DE["Saved: %s"]="Gespeichert: %s"
DE["Duration: %d min"]="Dauer: %d Min."
DE["Comment"]="Kommentar"
DE["%d pending applications · organized by you"]="%d offene Bewerbungen · von dir organisiert"
DE["%s, %d %s %d"]="%s, %d. %s %d"
DE["%s at %s"]="%s um %s"
DE["January"]="Januar";DE["February"]="Februar";DE["March"]="März";DE["April"]="April"
DE["May"]="Mai";DE["June"]="Juni";DE["July"]="Juli";DE["August"]="August"
DE["September"]="September";DE["October"]="Oktober";DE["November"]="November";DE["December"]="Dezember"
DE["New application"]="Neue Bewerbung"
DE["New help offer"]="Neues Hilfsangebot"
DE["%s applied for %s."]="%s hat sich auf %s beworben."
DE["%s withdrew from %s."]="%s hat die Bewerbung für %s zurückgezogen."
DE["%d more updates"]="%d weitere Meldungen"
DE["%s starts in 30 minutes."]="%s beginnt in 30 Minuten."
DE["%s starts in 10 minutes."]="%s beginnt in 10 Minuten."
DE["%s starts now."]="%s beginnt jetzt."
DE["Prepare the group and invite your confirmed participants."]="Bereite die Gruppe vor und lade deine bestätigten Teilnehmer ein."
DE["Your attendance is confirmed. Wait for the organizer to invite you."]="Deine Teilnahme ist bestätigt. Warte auf die Einladung des Veranstalters."
DE["Saved confirmation; organizer verification is pending."]="Gespeicherte Zusage; Abgleich mit dem Veranstalter steht aus."
DE["This event is still a private draft."]="Diese Aktivität ist noch ein privater Entwurf."
DE["Participant already has this status."]="Der Teilnehmer hat diesen Status bereits."
DE["Show"]="Anzeigen"
DE["Activity starts now"]="Aktivität beginnt jetzt"
DE["Activity reminder"]="Terminerinnerung"
DE["Application updated"]="Bewerbung aktualisiert"
DE["Participation updated"]="Teilnahme aktualisiert"
DE["Your attendance for %s: %s"]="Deine Teilnahme an %s: %s"
DE["%s was changed. Apply again."]="%s wurde geändert. Bewirb dich erneut."
DE["Your application for %s was accepted."]="Deine Bewerbung für %s wurde angenommen."
DE["Your application for %s was declined."]="Deine Bewerbung für %s wurde abgelehnt."
DE["You joined %s."]="Du bist der Gruppe für %s beigetreten."
DE["1/2 · Activity"]="1/2 · Aktivität"
DE["2/2 · Details"]="2/2 · Details"
DE["Details"]="Details"
DE["Quest assistance"]="Questhilfe"
DE["Date (YYYY-MM-DD)"]="Datum (JJJJ-MM-TT)"
DE["Time (HH:MM)"]="Uhrzeit (HH:MM)"
DE["Review the dates. Each date is saved as a private draft."]="Termine prüfen. Jeder Termin wird als privater Entwurf gespeichert."
DE["Craft count is the number of crafting operations."]="Anzahl der Herstellungsvorgänge, unabhängig von der gewünschten Stückzahl."
DE["Offer expires (minutes)"]="Laufzeit (Minuten)"
DE["Min. unit price (gold)"]="Stückpreis ab (Gold)"
DE["Max. unit price (gold)"]="Stückpreis bis (Gold)"
DE["Continues tomorrow"]="Endet am nächsten Tag"
DE["Unsaved changes"]="Ungespeicherte Änderungen"
DE["Message (optional)"]="Nachricht (optional)"
DE["Save"]="Speichern"
DE["Favorites / categories"]="Favoriten / Kategorien"
DE["Private contact categories"]="Private Kontaktkategorien"
DE["Category name"]="Kategoriename"
DE["Rename"]="Umbenennen"
DE["Add category"]="Kategorie hinzufügen"
DE["Delete category"]="Kategorie löschen"
DE["Remove category and its marks"]="Kategorie und ihre Markierungen entfernen"
DE["Category name must be 1 to 32 bytes."]="Der Kategoriename ist zu lang (maximal 32)."
DE["Enter a category name."]="Bitte einen Kategorienamen eingeben."
DE["This category name already exists."]="Dieser Kategoriename ist schon vorhanden."
DE["Maximum 20 private categories."]="Maximal 20 private Kategorien."
DE["Category ID limit reached."]="Keine weiteren Kategorienummern verfügbar."
DE["Date"]="Datum"
DE["Time"]="Uhrzeit"
DE["Comment (optional)"]="Kommentar (optional)"
DE["Solo"]="Solo"
DE["%d players in your group"]="%d Spieler in deiner Gruppe"
DE["Group size"]="Gruppengröße"
DE["Publish event"]="Termin veröffentlichen"
DE["Comment must be no more than 96 bytes."]="Der Kommentar ist zu lang (maximal 96)."
DE["Remove from my list"]="Aus meiner Liste entfernen"
DE["Local date or time is invalid or ambiguous. Choose another time."]="Datum oder lokale Uhrzeit ist ungültig oder mehrdeutig. Bitte eine andere Uhrzeit wählen."
DE["%d group roles unknown; check the needed roles."]="%d Gruppenrollen unbekannt; Rollenbedarf bitte prüfen."
DE["No application"]="Keine Anmeldung"
DE["Application submitted; awaiting response."]="Anmeldung gesendet; Antwort ausstehend."
DE["Withdrawal submitted."]="Rückzug gesendet."
DE["Saved application; organizer data is unavailable."]="Gespeicherte Anmeldung; Veranstalterdaten fehlen."
DE["Craft requests"]="Handwerksanfragen"
DE["Recipe catalog updated"]="Rezeptkatalog aktualisiert"
DE["Partial recipe scan"]="Teilscan des Rezeptkatalogs"
DE["Recipe updates by profession"]="Rezeptaktualisierungen nach Beruf"
DE["Not scanned yet"]="Noch nicht gescannt"
DE["%d recipes · %s"]="%d Rezepte · %s"
DE["recipes"]="Rezepte"
DE["Complete"]="Vollständig"
DE["Partial"]="Teilscan"
DE["Archive activity"]="Aktivität archivieren"
DE["Published activity"]="Veröffentlichte Aktivität"
DE["Private draft"]="Privater Entwurf"
DE["Update template"]="Vorlage aktualisieren"
DE["Archived activities"]="Archivierte Aktivitäten"
DE["No archived activities."]="Keine archivierten Aktivitäten."
DE["Select an archived activity."]="Wähle eine archivierte Aktivität aus."
DE["Archived on"]="Archiviert am"
DE["Activity archived."]="Aktivität archiviert."
DE["Activity cancelled"]="Aktivität abgesagt"
DE["%s was cancelled."]="%s wurde abgesagt."
DE["Archive this event? It will be cancelled and participants will be notified."]="Diesen Termin archivieren? Er wird abgesagt und die Teilnehmer werden benachrichtigt."
DE["Archive this activity? The public offer will end. Its details remain in the archive."]="Diese Aktivität archivieren? Das öffentliche Angebot endet. Die Details bleiben im Archiv erhalten."
DE["The activity changed. Reopen it before archiving."]="Die Aktivität hat sich geändert. Öffne sie vor dem Archivieren erneut."
DE["Private drafts are visible only to you until published."]="Private Entwürfe sind bis zur Veröffentlichung nur für dich sichtbar."
DE["Create again"]="Erneut erstellen"
DE["New activity"]="Neue Aktivität"
DE["Choose a new date and time, then create the activity."]="Wähle ein neues Datum und eine neue Uhrzeit und erstelle die Aktivität."
DE["The activity is published only when you click Create activity. Closing discards your input."]="Erst Aktivität erstellen veröffentlicht das Angebot. Beim Schließen werden die Eingaben verworfen."
DE["Archive your current group before creating another."]="Archiviere deine aktuelle Gruppe, bevor du eine neue erstellst."
DE["Archive your current quest request before creating another."]="Archiviere deine aktuelle Questanfrage, bevor du eine neue erstellst."
DE["Your existing request is open for editing."]="Deine vorhandene Anfrage ist zum Bearbeiten geöffnet."
DE["Review the dates. Create events publishes these dates with empty participant lists."]="Prüfe die Termine. Termine erstellen veröffentlicht sie mit leeren Teilnehmerlisten."
DE["Create events"]="Termine erstellen"
DE["Scheduled storage is full (100 events). Wait for archive cleanup."]="Terminspeicher ist voll (100 Termine). Warte auf die automatische Archivbereinigung."
DE["This activity is no longer active. Close the form and open it again."]="Diese Aktivität ist nicht mehr aktiv. Schließe das Formular und öffne sie erneut."
DE["Current party size"]="Aktuelle Gruppengröße"
DE["Invite all confirmed"]="Alle Bestätigten einladen"
DE["%d invitations sent; %d failed."]="%d Einladungen gesendet; %d fehlgeschlagen."
DE["Participants"]="Teilnehmer"
DE["Notifications"]="Benachrichtigungen"
DE["Last %d notifications"]="Letzte %d Benachrichtigungen"
DE["No notifications yet."]="Noch keine Benachrichtigungen."
DE["Online first"]="Online zuerst"
DE["Offer PvP help"]="PvP-Hilfe anbieten"
DE["I want to help. Notify me when someone needs help."]="Ich möchte helfen, benachrichtige mich, wenn jemand Hilfe benötigt."
DE["My help request"]="Mein Hilferuf"
DE["Help requests in the last 2 hours (%d)"]="Hilferufe der letzten 2 Stunden (%d)"
DE["Select a help request."]="Wähle einen Hilferuf aus."
DE["Coming to help"]="Kommt helfen"
DE["Commitment withdrawn"]="Zusage zurückgezogen"
DE["Withdraw commitment"]="Zusage zurückziehen"
DE["Your commitment was sent."]="Deine Zusage wurde gesendet."
DE["Targeted enemy"]="Anvisierter Gegner"
DE["%d minutes remaining · %d volunteers"]="Noch %d Minuten · %d Helfer zugesagt"
DE["Requested"]="Angefragt"
DE["Cancelled"]="Abgebrochen"
DE["Expired"]="Abgelaufen"
DE["Connection test pending"]="Verbindungstest ausstehend"
DE["Help offer withdrawn."]="Hilfsangebot zurückgezogen."
DE["Profile is already loading."]="Profil wird bereits geladen."
DE["Main"]="Main"
DE["Reached"]="Erreicht"
DE["Not reachable"]="Nicht erreichbar"
DE["Saved data"]="Datenstand gespeichert"
DE["|cff55ff55SCAN SUCCESSFUL|r\n"]="|cff55ff55SCAN ERFOLGREICH|r\n"
DE["Character data is not available yet."]="Charakterdaten sind noch nicht verfügbar."
DE["Addon messages are not available."]="Addon-Nachrichten sind nicht verfügbar."
DE["SCAN NOT RUN: First open your character's WoW profession window."]="SCAN NICHT AUSGEFÜHRT: Öffne zuerst das WoW-Berufsfenster deines Charakters."
DE["SCAN NOT RUN: Open the desired WoW profession window so its recipe list is visible."]="SCAN NICHT AUSGEFÜHRT: Öffne das gewünschte WoW-Berufsfenster, sodass seine Rezeptliste sichtbar ist."
DE["Linked professions are not saved as your own recipes."]="Verlinkte Berufe werden nicht als eigene Rezepte gespeichert."
DE["SCAN NOT RUN: The open profession could not be identified. Close foreign links and reopen your own profession window."]="SCAN NICHT AUSGEFÜHRT: Der geöffnete Beruf konnte nicht erkannt werden. Schließe fremde Links und öffne dein eigenes Berufsfenster erneut."
DE["SCAN NOT RUN: No learned recipes were found in this open profession window."]="SCAN NICHT AUSGEFÜHRT: In diesem geöffneten Berufsfenster wurden keine gelernten Rezepte gefunden."
DE["No valid map point."]="Kein gültiger Kartenpunkt."
DE["No waypoint is possible on this map."]="Auf dieser Karte ist kein Wegpunkt möglich."
DE["Map point not available."]="Kartenpunkt nicht verfügbar."
DE["Waypoint could not be set."]="Wegpunkt konnte nicht gesetzt werden."
DE["Player not known."]="Spieler nicht bekannt."
DE["The crafter cannot be reached."]="Der Handwerker ist nicht erreichbar."
DE["Crafting orders require ZenialCommunity 3.0."]="Für Herstellungsaufträge ist ZenialCommunity 3.0 erforderlich."
DE["Order data is invalid."]="Auftragsdaten sind ungültig."
DE["At most 100 active crafting orders."]="Maximal 100 laufende Herstellungsaufträge."
DE["At most five open requests per crafter."]="Maximal fünf offene Anfragen je Handwerker."
DE["Order is ambiguous."]="Auftrag ist mehrdeutig."
DE["Order not found."]="Auftrag nicht gefunden."
DE["This status change is not possible."]="Dieser Statuswechsel ist nicht möglich."
DE["The recipe is no longer in your own catalog."]="Das Rezept ist nicht mehr im eigenen Katalog."
DE["Invalid target."]="Ungültiges Ziel."
DE["Invalid scan data."]="Ungültige Scandaten."
DE["No valid recipes detected."]="Keine gültigen Rezepte erkannt."
DE["Profession data still incomplete."]="Berufsdaten noch unvollständig."
DE["First open your own WoW profession window."]="Öffne zuerst dein eigenes WoW-Berufsfenster."
DE["A call for help is already active."]="Es läuft bereits ein Hilferuf."
DE["A new call for help is possible only after ten minutes."]="Ein neuer Hilferuf ist erst nach zehn Minuten möglich."
DE["The message is too long."]="Die Nachricht ist zu lang."
DE["Location can only be updated every 30 seconds."]="Standort kann nur alle 30 Sekunden aktualisiert werden."
DE["Call for help is no longer active."]="Hilferuf nicht mehr aktiv."
DE["Invalid player."]="Ungültiger Spieler."
DE["At most 1,000 favorites."]="Maximal 1.000 Favoriten."
DE["Note is invalid."]="Notiz ist ungültig."
DE["Search rule is invalid."]="Suchregel ist ungültig."
DE["At most 20 saved searches."]="Maximal 20 gespeicherte Suchen."
DE["Offer not found."]="Angebot nicht gefunden."
DE["Local offer storage is full."]="Lokaler Angebotsspeicher ist voll."
DE["Draft is invalid."]="Entwurf ist ungültig."
DE["At most 20 templates."]="Maximal 20 Vorlagen."
DE["You no longer follow %s."]="Du folgst %s nicht mehr."
local reverse={}
for english,deutsch in pairs(DE)do reverse[deutsch]=english end
for english,deutsch in pairs(ACTIVITY_DE)do reverse[deutsch]=english end

DE["Quest Helper"]="Questhelfer"
DE["Shared Quests"]="Gemeinsame Quests"
DE["Help Requests"]="Hilfegesuche"
DE["My Help Request"]="Mein Hilfegesuch"
DE["Share my quests with the community"]="Meine Quests mit der Community teilen"
DE["Your group"]="Deine Gruppe"
DE["In group"]="In Gruppe"
DE["Busy"]="Beschäftigt"
DE["Available"]="Verfügbar"
DE["Find help for this quest"]="Hilfe für diese Quest suchen"
DE["Your existing request or draft is open for editing."]="Deine vorhandene Anfrage oder dein Entwurf ist zur Bearbeitung geöffnet."
DE["Quests"]="Quests"
DE["Other quests"]="Sonstige Quests"
DE["Fellow players"]="Mitspieler"
DE["Players with this quest"]="Spieler mit dieser Quest"
DE["%d quests"]="%d Quests"
DE["Select one of your quests."]="Wähle eine deiner Quests aus."
DE["Quest log scan pending. Close the map and leave combat."]="Questlog-Scan ausstehend. Schließe die Karte und verlasse den Kampf."
DE["Quest sharing is disabled."]="Questfreigabe ist deaktiviert."
DE["%d other shared quests"]="%d weitere gemeinsame Quests"
DE["No other players with this quest found."]="Keine anderen Spieler mit dieser Quest gefunden."
DE["Quest data unavailable."]="Questdaten sind nicht verfügbar."
DE["Quest match no longer available."]="Die Questübereinstimmung ist nicht mehr verfügbar."
DE["Player is unavailable or already grouped."]="Spieler ist nicht verfügbar oder bereits in einer Gruppe."
DE["Invitation pending."]="Einladung ausstehend."
DE["You cannot invite players."]="Du hast kein Einladungsrecht."
DE["The group is full."]="Die Gruppe ist voll."
DE["%d min ago"]="vor %d Min."
DE["%d h ago"]="vor %d Std."
DE["1 day ago"]="vor 1 Tag"
DE["Reading your quest log…"]="Dein Questlog wird gelesen…"
DE["Quest log could not be read. Details are available in Diagnostics."]="Questlog konnte nicht gelesen werden. Details findest du unter Diagnose."
DE["%d days ago"]="vor %d Tagen"
DE["Offline · recipes cannot be fetched"]="Offline · kein Rezeptabruf"
DE["Saved recipe data (offline)."]="Gespeicherte Rezeptdaten (offline)."

DE["Layer ID %d"]="Layer-ID %d"
DE["Layer unknown"]="Layer unbekannt"
DE["Backups"]="Backups"
DE["Delete backup"]="Backup löschen"
DE["Confirm deletion"]="Löschen bestätigen"
DE["No backups stored."]="Keine Backups gespeichert."
DE["Backups are kept until you delete them here. Deleting a backup cannot be undone."]="Backups bleiben erhalten, bis du sie hier löschst. Ein gelöschtes Backup kann nicht wiederhergestellt werden."
DE["Forever Live migration backup"]="Backup der Forever-Live-Migration"
DE["Character migration backup"]="Backup der Charaktermigration"
DE["Merged character profiles backup"]="Backup zusammengeführter Charakterprofile"

local I={locale=locale,isGerman=german,strings=DE,activities=ACTIVITY_DE}
local function atomic(value)
    local english=reverse[value]or value
    return german and(DE[english]or ACTIVITY_DE[english]or english)or english
end
function I.Text(value)
    if type(value)~="string"then return value end
    if reverse[value]or DE[value]or ACTIVITY_DE[value]then return atomic(value)end
    local prefix,body,suffix=value:match("^(|c%x+)(.-)(|r)$")
    if prefix then return prefix..atomic(body)..suffix end
    if value:find("\n",1,true)then
        local lines={};for line in (value.."\n"):gmatch("(.-)\n")do lines[#lines+1]=atomic(line)end
        return table.concat(lines,"\n")
    end
    return atomic(value)
end
function I.Format(value,...)
    local text=I.Text(value);if select("#",...)==0 then return text end
    local ok,result=pcall(string.format,text,...);return ok and result or text
end
function I.Role(value)return I.Text(({TANK="Tank",HEALER="Healer",DAMAGER="Damage"})[value]or value or"")end
function I.PeerState(value)local token=Z.Logic.PeerState(value);return token and I.Text(({reached="Reached",unreachable="Not reachable",saved="Saved data"})[token])or value or""end
function I.State(value)return I.Text(({applied="Applied",invited="Invited",rejected="Rejected",joined="Joined",withdrawn="Withdrawn"})[value]or value or"")end
function I.Activity(value)local id=Z.Logic and Z.Logic.ActivityID(value)or value;return german and(ACTIVITY_DE[id]or id)or id or""end
function I.Class(value,token)
    local id=token or value;local english=({WARRIOR="Warrior",PALADIN="Paladin",HUNTER="Hunter",ROGUE="Rogue",PRIEST="Priest",SHAMAN="Shaman",MAGE="Mage",WARLOCK="Warlock",DRUID="Druid"})[id]
    if not english then return value or I.Text("Unknown")end
    return german and(Z.Logic.CLASS_DE[id]or english)or english
end

Z.Locale=I
Z.T=function(value,...)return I.Format(value,...)end
