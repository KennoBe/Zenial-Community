local Z=ZenialCommunity

local locale=type(GetLocale)=="function"and GetLocale()or"enUS"
local german=locale=="deDE"

-- English is the source language. The reverse index keeps remaining German source
-- literals translatable while the UI moves to English keys without a flag day.
local DE={
    ["My guild"]="Meine Gilde",
    ["My guild only"]="Nur meine Gilde",
    ["Withdraw and verify an active application before forgetting it."]="Zieh zuerst die aktive Anmeldung zurück und warte auf Bestätigung. Danach kannst du den Termin entfernen.",
    ["This role has no scheduled slot."]="Für diese Rolle ist kein Platz vorgesehen.",
    ["Saved event starts in 30 minutes"]="Gespeicherter Termin beginnt in 30 Minuten",
    ["Saved event starts in 10 minutes"]="Gespeicherter Termin beginnt in 10 Minuten",
    ["Saved event starts now"]="Gespeicherter Termin beginnt jetzt",
    ["Saved state"]="Gespeicherter Status",
    ["Verification in progress"]="Abgleich läuft",
    ["No direct route"]="Keine direkte Verbindung",
    ["Awaiting organizer response"]="Antwort des Veranstalters ausstehend",
    ["Queued operation"]="Aktion vorgemerkt",
    ["Verified with organizer"]="Mit Veranstalter abgeglichen",
    ["No confirmed response"]="Keine bestätigte Antwort",
    ["Event changed; request rejected"]="Termin geändert; Anfrage abgelehnt",
    ["Application limit reached"]="Anmeldelimit erreicht",
    ["Registration closed"]="Anmeldung geschlossen",
    ["Event unavailable"]="Termin nicht verfügbar",
    ["Publication withdrawn"]="Veröffentlichung zurückgenommen",

    ["Reported online; not directly reachable"]="Online gemeldet · gerade nicht erreichbar",
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
    ["Local time conversion is unavailable or this clock time does not exist. Use an explicit UTC time."]="Diese Ortszeit ist ungültig oder nicht verfügbar. Gib die Zeit in UTC ein.",
    ["This local clock time occurs twice. Choose an explicit UTC time."]="Diese Ortszeit kommt zweimal vor. Bitte UTC explizit eingeben.",
    ["Local time conversion is unavailable."]="Die Ortszeit kann nicht umgerechnet werden.",
    ["Scheduled revision limit reached."]="Zu viele Änderungen an Terminen.",
    ["Saved scheduled groups are unavailable. Data was preserved."]="Gespeicherte Termine können nicht gelesen werden. Deine Daten bleiben erhalten.",
    ["Scheduled event fields are invalid."]="Terminfelder sind ungültig.",
    ["Organizer role needs a slot."]="Die Veranstalterrolle benötigt einen Platz.",
    ["Scheduled event changed or is no longer editable."]="Termin wurde geändert oder ist nicht mehr bearbeitbar.",
    ["Publishing scheduled groups is unavailable."]="Terminveröffentlichung ist nicht verfügbar.",
    ["Publish no more than ten upcoming events."]="Höchstens zehn kommende Termine veröffentlichen.",
    ["Scheduled event changed or is closed."]="Termin wurde geändert oder ist geschlossen.",
    ["Only unused private drafts can be deleted."]="Nur unbenutzte private Entwürfe können gelöscht werden.",
    ["No more than twenty recurrence templates."]="Höchstens zwanzig Wiederholungsvorlagen.",
    ["Choose one to four upcoming instances."]="Wähle ein bis vier kommende Termine.",
    ["Client timezone changed. Create a new recurrence template."]="Clientzeitzone wurde geändert. Neue Wiederholungsvorlage anlegen.",
    ["Events must start within ninety days."]="Termine müssen innerhalb von neunzig Tagen beginnen.",
    ["Recurrence preview changed. Review it again."]="Wiederholungsvorschau wurde geändert. Erneut prüfen.",
    ["Scheduled groups unsupported or not yet verified"]="Terminfunktion fehlt oder ist noch nicht bestätigt",
    ["Organizer offline or not directly reachable"]="Veranstalter offline oder gerade nicht kontaktierbar",
    ["Scheduled subscription storage is unavailable or full."]="Speicher für Terminanmeldungen ist nicht verfügbar oder voll.",
    ["Verify the event with its organizer before applying."]="Termin vor der Anmeldung mit dem Veranstalter abgleichen.",
    ["No active scheduled application to withdraw."]="Keine aktive Terminanmeldung zum Zurückziehen.",
    ["Application changed or event is closed."]="Anmeldung wurde geändert oder Termin ist geschlossen.",
    ["This role is already full. Use the waitlist."]="Diese Rolle ist bereits voll. Bitte Ersatzbank verwenden.",
    ["No application"]="Keine Anmeldung",
    ["Application pending"]="Anmeldung ausstehend",
    ["Saved state; verification pending"]="Rückmeldung zur Anmeldung ausstehend",
    ["Scheduled change saved."]="Terminänderung gespeichert.",
    ["Editing a published event invalidates existing applications. Participants must apply again."]="Änderungen entwerten bestehende Anmeldungen. Teilnehmer müssen sich neu anmelden.",
    ["%d events · page %d/%d"]="%d Termine · Seite %d/%d",
    ["Invalid scheduled data was rejected."]="Ungültige Termindaten wurden abgelehnt.",
    ["Select a scheduled event."]="Wähle einen Termin.",
    ["Delivery: "]="Zustellung: ",
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
    ["Weekly instances: same organizer local time"]="Wöchentlich zur gleichen Ortszeit des Veranstalters",
    ["Number of instances"]="Anzahl der Termine",
    ["Preview dates"]="Termine vorab prüfen",
    ["Scheduled application changed"]="Terminanmeldung geändert",
    ["Scheduled participation updated"]="Terminteilnahme aktualisiert",
    ["Scheduled event changed; apply again"]="Termin geändert; erneut anmelden",
    ["Reminder for a saved event"]="Erinnerung an gespeicherten Termin",
    ["Applications"]="Bewerbungen",
    ["Private event"]="Privater Termin",

    ["Continue craft request"]="Herstellungsanfrage fortsetzen",
    ["Material planning"]="Materialplanung",
    ["Crafts for material planning"]="Herstellungsvorgänge",
    ["Show materials"]="Materialien anzeigen",
    ["Save list"]="Liste speichern",
    ["Offers"]="Angebotsliste",
    ["Need %d · Available %s · Missing %s"]="Benötigt %d · Verfügbar %s · Fehlt %s",
    ["Bag quantity unknown."]="Taschenbestand unbekannt.",
    ["In bags: %s"]="In Taschen: %s",
    ["Reserved for other lists: %s"]="Für andere Listen reserviert: %s",
    ["Crafts to plan"]="Herstellungen",
    ["Set craft count explicitly; recipe yield is unknown."]="Lege die Zahl der Herstellungen selbst fest; die Rezeptausbeute ist unbekannt.",
    ["Save shopping list"]="Einkaufsliste speichern",
    ["Open shopping lists"]="Einkaufslisten öffnen",
    ["Private shopping list saved."]="Private Einkaufsliste gespeichert.",
    ["Ingredient data is invalid."]="Zutatendaten sind ungültig.",
    ["Material quantities are too large."]="Materialmengen sind zu groß.",
    ["Recipe data is unavailable."]="Rezeptdaten sind nicht verfügbar.",
    ["Craft count must be 1 to 100000."]="Vorgänge müssen zwischen 1 und 100000 liegen.",
    ["Saved material plans use an unsupported version. Data was preserved."]="Diese gespeicherten Einkaufslisten stammen aus einer neueren Version. Sie bleiben unverändert erhalten.",
    ["Order is unavailable."]="Auftrag ist nicht verfügbar.",
    ["This shopping list already belongs to another order."]="Diese Einkaufsliste gehört bereits zu einem anderen Auftrag.",
    ["This order already has a shopping list."]="Dieser Auftrag hat bereits eine Einkaufsliste.",
    ["Shopping list storage is full (100 lists)."]="Du kannst höchstens 100 Einkaufslisten speichern.",
    ["This material plan is closed or its order is unavailable."]="Dieser Materialplan ist geschlossen oder sein Auftrag nicht verfügbar.",
    ["Manual amount is invalid."]="Manuelle Menge ist ungültig.",
    ["%d crafts · %s"]="%d Vorgänge · %s",
    ["Private list"]="Private Liste",
    ["Order unavailable"]="Auftrag nicht verfügbar",
    ["Invalid material plans were discarded."]="Ungültige Materialpläne wurden verworfen.",
    ["Private shopping lists (maximum 100)."]="Private Einkaufslisten (maximal 100).",
    ["Select a private shopping list."]="Wähle eine private Einkaufsliste.",
    ["Bags only; oldest active list reserves first."]="Nur Taschen zählen. Ältere Listen werden zuerst berücksichtigt.",
    ["Manual marks do not confirm inventory or handoff."]="Eine Markierung heißt nicht, dass du es im Inventar hast oder übergeben hast.",
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
    ["Ingredient list completeness is unverified."]="Die Zutatenliste wurde nicht auf Vollständigkeit geprüft.",

    ["Today"]="Heute",
    ["Questing"]="Quests erledigen",
    ["Dungeon"]="Dungeon",["Raid"]="Raid",
    ["Level together"]="Zusammen leveln",
    ["Goal"]="Ziel",
    ["Duration (minutes)"]="Laufzeit (Minuten)",
    ["Server time is unavailable."]="Die Serverzeit ist nicht verfügbar.",
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
    ["Nothing stored locally. Drafts, templates and finished offers appear after you create an offer."]="Noch keine Einträge. Deine Entwürfe, Vorlagen und beendeten Angebote findest du hier.",
    ["No events in this period. Widen the period or reset the filters."]="Keine Ereignisse in diesem Zeitraum. Erweitere den Zeitraum oder setze die Filter zurück.",
    ["Drag to resize the window."]="Ziehen, um die Fenstergröße zu ändern.",
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
    ["Macro browser, hidden graphics settings, map reveal and small everyday helpers."]="Makro-Browser, versteckte Grafikeinstellungen, Karte aufdecken und kleine Alltagshelfer.",
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
    ["New update"]="Neue Meldung",
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
    ["WoW project data is unavailable. Copy diagnostics."]="Die WoW-Projektkennung fehlt. Bitte Diagnose kopieren.",
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
    ["Battle.net network · 4.0"]="Battle.net-Netzwerk · 4.0",
    ["Community connection"]="Community-Verbindung",
    ["Community exchange is disabled."]="Der Community-Austausch ist deaktiviert.",
    ["Community member search is paused."]="Die Suche nach Community-Mitgliedern ist pausiert.",
    ["Join the community to connect."]="Tritt der Community bei, um dich zu verbinden.",
    ["Checking community membership."]="Community-Beitritt wird geprüft.",
    ["Connected to the community."]="Mit der Community verbunden.",
    ["Searching for active community members."]="Suche nach aktiven Community-Mitgliedern.",
    ["Battle.net is not sharing your character right now, so other players cannot find you. To fix it: log out, turn off all addons, enter the world, log out again, turn the addons back on and enter the world."]="Battle.net teilt deinen Charakter gerade nicht, deshalb können dich andere nicht finden. So behebst du es: ausloggen, alle Addons ausschalten, ins Spiel gehen, wieder ausloggen, Addons einschalten und ins Spiel gehen.",
    ["Connect with other players to find members and community activity."]="Verbinde dich mit anderen Spielern, um Mitglieder und Aktivitäten zu finden.",
    ["Refresh connection"]="Verbindung aktualisieren",
    ["Connection check started. It may take a moment."]="Verbindungstest gestartet. Das kann einen Moment dauern.",
    ["The connection cannot be checked yet. Please try again shortly."]="Die Verbindung kann gerade nicht geprüft werden. Bitte versuche es gleich erneut.",
    ["Technical details"]="Technische Details",
    ["Set up ZENIAL Community to find members and offers. Public entries are shared; private requests go directly to their owner."]="ZENIAL Community einrichten, um Mitglieder und Angebote zu finden. Öffentliche Einträge werden geteilt; private Anfragen gehen direkt zum Besitzer.",
    ["Invitation links"]="Einladungslinks",
    ["Invitation link"]="Einladungslink",
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
    ["Battle.net network connected"]="Battle.net-Netzwerk verbunden",
    ["Waiting for lounge membership"]="Warte auf Lounge-Beitritt",
    ["No matching players in lounge"]="Keine passenden Spieler in der Lounge",
    ["Excluded accounts: %s"]="Ausgefilterte Spielkonten: %s",
    ["Sent: %d · received: %d · rejected: %d · timeouts: %d"]="Gesendet: %d · empfangen: %d · verworfen: %d · abgelaufen: %d",
    ["Diagnostic report"]="Diagnosebericht",["Copy diagnostics"]="Diagnose kopieren",["Select all"]="Alles markieren",
    ["Members"]="Mitglieder",["Crafting"]="Handwerk",["Groups"]="Gruppen",["Quest Help"]="Questhilfe",["Trade"]="Handel",["Profile"]="Profil",["History"]="Historie",["Addon Manager"]="Addon Manager",
    ["Status"]="Status",["Class"]="Klasse",["Profession"]="Beruf",["Sort"]="Sortierung",["All"]="Alle",["Online"]="Online",["All classes"]="Alle Klassen",["All professions"]="Alle Berufe",["Name A–Z"]="Name A–Z",["Level ascending"]="Level aufsteigend",["Level descending"]="Level absteigend",["Last seen"]="Zuletzt gesehen",["Alliance"]="Allianz",["Unknown"]="Unbekannt",["never"]="nie",["just now"]="gerade eben",["You"]="Du",["member"]="Mitglied",["members"]="Mitglieder",["Guild"]="Gilde",["Professions"]="Berufe",["Role"]="Rolle",["Display name"]="Anzeigename",["Level"]="Level",["Version"]="Version",["Current"]="Vorhanden",["Needed"]="Gesucht",["Price"]="Preis",["PREVIEW"]="VORSCHAU",["YOUR CHARACTER"]="DEIN CHARAKTER",
    ["Group Search"]="Gruppe suchen",["My Group"]="Meine Gruppe",["My Applications"]="Meine Bewerbungen",["Follow Activities"]="Aktivitäten folgen",["PvP Help"]="PvP-Hilfe",["Quest Requests"]="Questanfragen",["My Quest Request"]="Meine Questanfrage",["My Help Offers"]="Meine Hilfsangebote",
    ["My Offers"]="Meine Angebote",["Character Profile"]="Charakterprofil",["Appearance"]="Darstellung",
    ["Select"]="Auswählen",["Refresh"]="Aktualisieren",["Reset"]="Zurücksetzen",["Reset filters"]="Filter zurücksetzen",["Back"]="Zurück",["← Back to list"]="← Zurück zur Liste",["Cancel"]="Abbrechen",["Delete"]="Löschen",["Edit"]="Bearbeiten",["Whisper"]="Anflüstern",["Invite to group"]="In Gruppe einladen",
    ["Apply"]="Bewerbung senden",["Withdraw"]="Zurückziehen",["Withdraw application"]="Bewerbung zurückziehen",["Accept & invite"]="Annehmen & einladen",["Reject"]="Ablehnen",["Offer help"]="Hilfe anbieten",["Withdraw help offer"]="Hilfsangebot zurückziehen",["Show full history"]="Gesamten Verlauf anzeigen",
    ["Create group"]="Gruppe erstellen",["Publish group"]="Gruppe veröffentlichen",["Create quest request"]="Questanfrage erstellen",["Publish quest request"]="Questanfrage veröffentlichen",["Publish offer"]="Angebot veröffentlichen",["Discard draft"]="Entwurf verwerfen",["Save changes"]="Änderungen speichern",
    ["Category"]="Kategorie",["Activity"]="Aktivität",["Search activity"]="Aktivität suchen",["All categories"]="Alle Kategorien",["All activities"]="Alle Aktivitäten",["Custom activity"]="Eigene Aktivität",["Dungeons"]="Dungeons",["Raids"]="Raids",
    ["Level from"]="Level von",["Level to"]="Level bis",["Target size"]="Zielgröße",["Tank needed"]="Tank gesucht",["Healer needed"]="Heiler gesucht",["Damage needed"]="DD gesucht",["Current group"]="Vorhandene Gruppe",["Note (optional)"]="Notiz (optional)",["Search notes"]="Notiz durchsuchen",["My role"]="Meine Rolle",["Application note (optional)"]="Bewerbungsnotiz (optional)",
    ["No preference"]="Keine Angabe",["Tank"]="Tank",["Healer"]="Heiler",["Damage"]="DD",["Role not assigned"]="Rollen nicht zugewiesen",["Solo"]="Solo",
    ["Applied"]="Beworben",["Invited"]="Eingeladen",["Rejected"]="Abgelehnt",["Joined"]="Beigetreten",["Withdrawn"]="Zurückgezogen",
    ["Select a member."]="Wähle ein Mitglied aus.",["Select a group."]="Wähle eine Gruppe aus.",["Select an application."]="Wähle eine Bewerbung aus.",["Select a quest request."]="Wähle eine Questanfrage aus.",["Select a help offer."]="Wähle ein Hilfsangebot aus.",["Select an offer."]="Wähle ein Angebot aus.",["Select an active PvP help request."]="Wähle einen aktiven PvP-Hilferuf aus.",["Select an entry to view the request timeline."]="Wähle einen Eintrag aus, um den Verlauf der Anfrage zu sehen.",["Select a followed activity on the left."]="Wähle links eine gefolgte Aktivität aus.",
    ["No active group."]="Du hast keine aktive Gruppe.",["No active quest request."]="Du hast keine aktive Questanfrage.",["No offers match the filter."]="Keine Angebote entsprechen dem Filter.",["No matching crafters or recipes found."]="Keine passenden Handwerker oder Rezepte gefunden.",["Profile not received yet"]="Profil noch nicht empfangen",
    ["Current location"]="Aufenthaltsort",["Current location:"]="Aufenthaltsort:",["Location"]="Ort",["Location:"]="Ort:",["Location unknown"]="Ort unbekannt",["Last known location"]="Letzter bekannter Ort",["Leader location"]="Leader-Ort",["Applicant location"]="Aufenthaltsort des Bewerbers",["Helper location"]="Aufenthaltsort des Helfers",["Leader current location"]="Aufenthaltsort des Leaders",["Quest area"]="Questgebiet",
    ["Incoming applicants"]="Eigene Bewerber",["My helpers"]="Eigene Helfer",["Previous contacts"]="Bisherige Kontakte",["Choose an applicant."]="Wähle einen Bewerber aus.",["Choose a helper."]="Wähle einen Helfer aus.",["No previous contacts stored."]="Noch keine früheren Kontakte gespeichert.",
    ["The logged-in character cannot be removed."]="Der eingeloggte Charakter kann nicht entfernt werden.",["Select a character on your server and faction."]="Wähle einen Charakter deines Servers und deiner Fraktion.",
    ["Profession data is not ready yet."]="Die Berufsdaten sind noch nicht vollständig verfügbar.",["This profession is no longer learned."]="Dieser Beruf ist nicht mehr erlernt.",
    ["Main character"]="Hauptcharakter",["Recorded deaths in the last 60 minutes: %d / 2"]="Erfasste Tode in den letzten 60 Minuten: %d / 2",
    ["Player, title or note"]="Spieler, Titel oder Notiz",["Zone"]="Zone",["Level"]="Level",["From quest log"]="Aus dem Questlog",["Manual / level group"]="Manuell / Levelgruppe",["Search quests"]="Quest suchen",["Title / level group"]="Titel / Levelgruppe",["Zone (optional)"]="Zone (optional)",["Duration in minutes"]="Ablauf in Minuten",["Message (optional)"]="Nachricht (optional)",
    ["Item, service or player"]="Gegenstand, Dienstleistung oder Spieler",["Type"]="Art",["Sell"]="Verkaufen",["Buy"]="Kaufen",["Service"]="Dienstleistung",["Wanted"]="Suche",["For sale"]="Verkaufe",["Item or service"]="Gegenstand oder Dienstleistung",["Quantity"]="Menge",["Total price gold"]="Gesamtpreis Gold",["Silver"]="Silber",["Copper"]="Kupfer",["Duration in minutes (max. 1440)"]="Ablauf in Minuten (max. 1440)",["offer"]="Angebot",["offers"]="Angebote",
    ["All item categories"]="Alle Gegenstandskategorien",["Weapons"]="Waffen",["Armor"]="Rüstung",["Bags"]="Taschen",["Consumables"]="Verbrauchsgüter",["Materials"]="Materialien",["Ammunition"]="Munition",["Recipes"]="Rezepte",["Quest items"]="Questgegenstände",["Miscellaneous"]="Sonstiges",["Unclassified"]="Nicht zugeordnet",["Unit price"]="Stückpreis",["Total price"]="Gesamtpreis",["Minimum unit price (gold)"]="Stückpreis min. (Gold)",["Maximum unit price (gold)"]="Stückpreis max. (Gold)",["Name"]="Name",["Unit price ascending"]="Stückpreis aufsteigend",["Unit price descending"]="Stückpreis absteigend",["Ending soon"]="Endet bald",["Invalid price filter"]="Ungültiger Preisfilter",
    ["Display name (optional)"]="Anzeigename (optional)",["Preferred role"]="Bevorzugte Rolle",["Save profile"]="Profil speichern",["Show profile in Members"]="Profil bei Mitglieder zeigen",["Set as main character"]="Als Hauptcharakter festlegen",["Default size"]="Standardgröße",["Reset position"]="Position zurücksetzen",
    ["Period"]="Zeitraum",["Last 7 days"]="Letzte 7 Tage",["Last 30 days"]="Letzte 30 Tage",["Last 90 days"]="Letzte 90 Tage",["Area"]="Bereich",["All areas"]="Alle Bereiche",["Own character"]="Eigener Charakter",["All characters"]="Alle Charaktere",["Player or content"]="Spieler oder Inhalt",["Delete player history"]="Spieler-Historie löschen",["Delete history"]="Historie löschen",
    ["Choose activities you want to be notified about when a new group is published."]="Wähle Aktivitäten aus, bei deren neu veröffentlichten Gruppen du benachrichtigt werden möchtest.",["Follow"]="Folgen",["Stop following"]="Nicht mehr folgen",
    ["Receive PvP help requests"]="PvP-Hilferufe empfangen",["Area filter"]="Gebietsfilter",["All zones"]="Alle Gebiete",["Only my current zone"]="Nur meine aktuelle Zone",["I'm coming"]="Ich komme",["Show on map"]="Auf Karte zeigen",["Set waypoint"]="Wegpunkt setzen",["Block"]="Blockieren",["I'm being ganked. HELP!"]="Werde gegankt. HILFE!",["Update location"]="Standort aktualisieren",["Done"]="Erledigt",["Helpers committed"]="Helfer zugesagt",["Invite"]="Einladen",["Who is attacking you? Number and level (optional, e.g. 3 × level 60)"]="Wer greift dich an? Anzahl und Level (optional, z. B. 3× Level 60)",["I am being attacked by players"]="Ich werde von Spielern angegriffen",["Call for help"]="Hilfe rufen",
    ["My professions"]="Meine Berufe",["MY PROFESSIONS"]="MEINE BERUFE",["APPEARANCE"]="DARSTELLUNG",["Scan professions"]="Berufe scannen",["Recipe, item or profession"]="Rezept, Gegenstand oder Beruf",
    ["WoW Forever Discord"]="WoW Forever Discord",
    ["Crit and last-hit effects with graphics, sound and a freely selectable position."]="Krit- und Last-Hit-Effekte mit Grafik, Klang und frei wählbarer Position.",["Local gunfire and reload sounds with random or fixed selection."]="Lokale Gewehr- und Nachladeklänge mit Zufalls- oder Festwahl.",["Local event and API capture for addon development."]="Lokaler Event- und API-Mitschnitt für die Addon-Entwicklung.",["Embedded interface could not be created."]="Eingebettete Oberfläche konnte nicht erstellt werden.",
    ["Installed and loaded"]="Installiert und geladen",["Not installed"]="Nicht installiert",["Installed but disabled"]="Installiert, aber deaktiviert",["Loading"]="Wird geladen",["Not loadable"]="Nicht ladbar",["Installed · available after /reload"]="Installiert · nach /reload verfügbar",["Installed · embedding update required"]="Installiert · Update für Einbettung erforderlich",["Open addon window"]="Addonfenster öffnen",["Open settings"]="Einstellungen öffnen",["Messenger with conversations and a shared local history."]="Messenger mit Gesprächen und gemeinsamem lokalen Verlauf.",["Unit frames, action bars, nameplates and cast bars with a layout editor."]="Einheitenframes, Aktionsleisten, Namensplaketten und Castbars mit Layout-Editor.",["Enable in AddOns menu"]="Im Addonmenü aktivieren",["/reload required"]="/reload erforderlich",
    ["Application sent."]="Bewerbung gesendet.",["Application withdrawn."]="Bewerbung zurückgezogen.",["Help offer sent."]="Hilfeangebot gesendet.",["Invitation sent."]="Einladung gesendet.",["Profile saved."]="Profil gespeichert.",["Offer saved."]="Angebot gespeichert.",["Location updated."]="Standort aktualisiert.",["Help request ended."]="Hilferuf beendet.",["Help request is being sent."]="Hilferuf wird versendet.",["Commitment sent."]="Zusage gesendet.",["Commitment withdrawn."]="Zusage zurückgezogen.",["Waypoint set."]="Wegpunkt gesetzt.",
    ["The group is no longer active."]="Die Gruppe ist nicht mehr aktiv.",["The quest request is no longer active."]="Die Questanfrage ist nicht mehr aktiv.",["You already applied."]="Du hast dich bereits beworben.",["You already offered help."]="Du hast bereits Hilfe angeboten.",["No active application."]="Keine aktive Bewerbung.",["No active help offer."]="Kein aktives Hilfeangebot.",["Application is no longer active."]="Bewerbung nicht mehr aktiv.",["Help offer is no longer active."]="Hilfsangebot nicht mehr aktiv.",["Invalid role."]="Ungültige Rolle.",["Exchange unavailable."]="Austausch nicht verfügbar.",["Queue full."]="Warteschlange voll.",["Data is invalid or too large."]="Daten sind ungültig oder zu groß.",
    ["Please enter a valid activity."]="Bitte eine gültige Aktivität angeben.",["Please enter a title or level group."]="Bitte einen Titel oder eine Levelgruppe angeben.",["Please enter an item or service."]="Bitte einen Gegenstand oder eine Dienstleistung angeben.",["Input is too long."]="Eingabe ist zu lang.",["Item not found."]="Gegenstand nicht gefunden.",["The target size has already been reached."]="Die Zielgröße ist bereits erreicht.",["Confirm first that players are attacking you."]="Bestätige zuerst, dass Spieler dich angreifen.",
    ["Group published"]="Gruppe veröffentlicht",["Group updated"]="Gruppe aktualisiert",["Group closed"]="Gruppe geschlossen",["Group expired"]="Gruppe abgelaufen",["Quest request created"]="Questanfrage erstellt",["Quest request updated"]="Questanfrage geändert",["Quest request closed"]="Questanfrage geschlossen",["Quest request expired"]="Questanfrage abgelaufen",
    ["Application received"]="Bewerbung erhalten",["Application queued"]="Versand vorgemerkt",["Application delivered"]="Versand bestätigt",["Application failed"]="Versand fehlgeschlagen",["Application withdrawn"]="Bewerbung zurückgezogen",["Withdrawal received"]="Rücknahme erhalten",["Invitation sent"]="Einladung gesendet",["Invitation received"]="Einladung erhalten",["Rejection sent"]="Ablehnung gesendet",["Rejection received"]="Ablehnung erhalten",["Observed together in group"]="Gemeinsam in Gruppe beobachtet",["Delivery pending"]="Versand vorgemerkt",["Transport confirmed"]="Übertragung bestätigt",["Delivery failed"]="Versand fehlgeschlagen",["Status transfer unknown"]="Zustellung nicht bestätigt",["Area unknown"]="Gebiet unbekannt",
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
    ["Pause"]="Pausieren",["Duplicate"]="Duplizieren",["Completed"]="Erledigt",["Open / relist"]="Öffnen / erneut anbieten",
    ["Save as template"]="Als Vorlage speichern",["Save as local draft"]="Als lokalen Entwurf speichern",
    ["My level matches"]="Mein Level passt",["My role is needed"]="Meine Rolle wird gesucht",["Available leaders only"]="Nur verfügbare Leiter",["Choose a preferred role in your profile to use the role filter."]="Wähle im Profil eine bevorzugte Rolle, um den Rollenfilter zu verwenden.",
    ["Template"]="Vorlage",["Use template"]="Vorlage verwenden",["Request crafting"]="Herstellung anfragen",["Check again now"]="Jetzt erneut prüfen",
    ["Create group or template"]="Gruppe oder Vorlage erstellen",["Manage templates"]="Vorlagen verwalten",["Choose template"]="Vorlage wählen",["Delete template"]="Vorlage löschen",
    ["Template name"]="Vorlagenname",["Duration (min.)"]="Laufzeit (Min.)",["Save template"]="Vorlage speichern",
    ["Choose a template first."]="Wähle zuerst eine Vorlage.",["Group template deleted."]="Gruppenvorlage gelöscht.",
    ["Please enter a template name."]="Bitte einen Vorlagennamen angeben.",["The duration must be between 1 and 1440 minutes."]="Die Laufzeit muss zwischen 1 und 1440 Minuten liegen.",["Group template saved. It was not published."]="Gruppenvorlage gespeichert. Sie wurde nicht veröffentlicht.",
    ["Template is invalid."]="Vorlage ist ungültig.",["A maximum of 20 group templates is allowed."]="Maximal 20 Gruppenvorlagen.",
    ["Private note"]="Private Notiz",["Favorite"]="Favorit",["Search"]="Suchen",
    ["Transmission throttled"]="Übertragung gedrosselt",["Connected"]="Verbunden",
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


DE["Visible profile"]="Profil sichtbar machen"
DE["Share professions and recipes"]="Berufe und Rezepte teilen"

DE["Request from %s: %s"]="Anfrage an %s: %s"

DE["Private note saved."]="Private Notiz gespeichert."
DE["Broadcast queued"]="Versand vorgemerkt"
DE["Broadcast sent"]="Hilferuf gesendet"
DE["Broadcast failed"]="Versand fehlgeschlagen"
DE["Waiting to broadcast"]="Warte auf Versand"
DE["ACTIVE PVP HELP REQUEST"]="AKTIVER PVP-HILFERUF"


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


DE[" is received."]=" empfangen wird."
DE[" checked · "]=" geprüft · "
DE[" saved searches"]=" gespeicherte Suchen"
DE[" is invalid."]=" ist ungültig."
DE[" local entries"]=" lokale Einträge"
DE[" new groups for followed activities\nClick to open"]=" neue Gruppen für gefolgte Aktivitäten\nKlicken zum Öffnen"
DE[" new PvP help requests\nClick to open"]=" neue PvP-Hilferufe\nKlicken zum Öffnen"

DE[" open groups"]=" offene Gruppen"
DE[" no response"]=" ohne Antwort"
DE[" really delete?"]=" wirklich löschen?"
DE[" · Click to open"]=" · Klicken zum Öffnen"

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

DE["All history entries for "]="Alle Historieneinträge zu "
DE["Send request"]="Anfrage senden"
DE["Offer template saved."]="Angebotsvorlage gespeichert."
DE["Accepted"]="Angenommen"

DE["Location\nSelect an applicant."]="Aufenthaltsort\nWähle einen Bewerber aus."
DE["Location\nSelect a helper."]="Aufenthaltsort\nWähle einen Helfer aus."
DE["Order updated."]="Auftrag aktualisiert."
DE["Outgoing"]="Ausgang"
DE["Incoming"]="Eingang"


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

DE["Recorded professions: "]="Erfasste Berufe: "

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



DE["\nThis player can craft the requested recipe."]="\nDieser Spieler kann das gesuchte Rezept herstellen."
DE["\nClick to open"]="\nKlicken zum Öffnen"
DE["\nLast recipe scan: "]="\nLetzter Rezeptscan: "
DE["\nTime remaining: "]="\nLäuft noch "
DE["\nMaterials: "]="\nMaterialien: "
DE["\nRecipe catalog: "]="\nRezeptkatalog: "
DE["\nSelect a recipe on the right."]="\nWähle rechts ein Rezept aus."






DE["not run yet"]="noch nicht ausgeführt"
DE["provided"]="werden gestellt"
DE["not provided"]="nicht gestellt"
DE["|cffff5555SCAN NOT RUN|r\n"]="|cffff5555SCAN NICHT AUSGEFÜHRT|r\n"
DE["|cffff5555IMPORTANT: OPEN THE CORRECT PROFESSION WINDOW|r"]="|cffff5555WICHTIG: DAS PASSENDE BERUFSFENSTER MUSS GEÖFFNET SEIN|r"
DE["|cffffd36bREQUEST CRAFTING|r"]="|cffffd36bHERSTELLUNG ANFRAGEN|r"

DE["|r\nNew matching offers, changes and closures trigger a local alert. Existing results after login remain quiet."]="|r\nNeue passende Angebote, Änderungen und Schließungen erzeugen einen lokalen Hinweis. Bestehende Treffer nach Login bleiben still."
DE["|r\nRecipe in the catalog of "]="|r\nRezept im Katalog von "

DE["Open your own profession window and keep the recipe list visible. ZenialCommunity scans automatically. If a complete unfiltered list is not safely available, found recipes are only added and the previous complete catalog is preserved."]="Öffne dein eigenes WoW-Berufsfenster und lasse die Rezeptliste sichtbar. ZenialCommunity scannt dann automatisch. Ist die vollständige ungefilterte Liste nicht sicher verfügbar, werden erkannte Rezepte nur ergänzt und nichts aus dem letzten vollständigen Stand gelöscht."
DE["Confirm handoff"]="Übergabe bestätigen"
DE["Handoff confirmed"]="Übergabe bestätigt"
DE["Another %d death(s) needed before requesting help."]="Noch %d Tod/Tode bis zum Hilferuf."
DE["You must be flagged for PvP to request help."]="Du musst für PvP markiert sein, um Hilfe anzufordern."
DE["%d recipes found for %s."]="%d Rezepte für %s erkannt."
DE["Complete: %s"]="Vollständig: %s"
DE["Partial scan: %s"]="Teilscan: %s"
DE["Expand your skill categories to update professions safely."]="Klappe deine Fertigkeitskategorien auf, damit die Berufe sicher aktualisiert werden können."
DE["Own profession data is not ready yet."]="Eigene Berufsdaten sind noch nicht verfügbar."
DE["Ctrl+C to copy"]="Strg+C zum Kopieren"
DE["Attackers"]="Angreifer"
DE["Place of death"]="Todesort"
DE["Help request less than a minute ago"]="Hilferuf vor weniger als einer Minute"
DE["Help request %d min ago"]="Hilferuf vor %d Min."
DE["PvP help needed"]="PvP-Hilfe gesucht"
DE[" needs PvP help"]=" braucht PvP-Hilfe"
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


DE["Enchanter"]="Verzauberer"
DE["Leveling partner"]="Levelpartner"

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


DE["Saved activity"]="Gespeicherte Aktivität"
DE["Saved application"]="Gespeicherte Anmeldung"
DE["This activity is no longer available."]="Diese Aktivität ist nicht mehr verfügbar."
DE["%d activities · page %d/%d"]="%d Aktivitäten · Seite %d/%d"
DE["All details"]="Alle Details"
DE["Manage applicants"]="Bewerber verwalten"
DE["Select an activity to see its details and actions."]="Wähle eine Aktivität, um Details und Aktionen zu sehen."









DE["Next appointments"]="Nächste Termine"

DE["Creates a live request that you review before it is published."]="Erstellt eine Live-Anfrage, die du vor der Veröffentlichung prüfst."
DE["Creates a scheduled event that others can apply to after you publish it."]="Erstellt einen Termin, auf den sich andere nach der Veröffentlichung bewerben können."


DE["Create activity"]="Aktivität erstellen"
DE["Open activity"]="Aktivität öffnen"
DE["Enter an activity."]="Gib eine Aktivität ein."


DE["Back to today"]="Zurück zu Heute"
DE["Character profile"]="Charakterprofil"

DE["Display settings"]="Darstellung"
DE["Contact history"]="Kontaktverlauf"
DE["All shopping lists"]="Alle Materiallisten"
DE["All requests"]="Alle"
DE["Incoming requests"]="Eingehend"
DE["Outgoing requests"]="Ausgehend"
DE["Shopping lists"]="Einkaufslisten"
DE["Materials for this recipe"]="Materialien für dieses Rezept"
DE["View offers"]="Angebote ansehen"
DE["Back to orders"]="Zurück zu Aufträgen"
DE["Shared quests"]="Gemeinsame Quests"
DE["Quest groups"]="Questgruppen"
DE["Follow activities"]="Gemerkte Aktivitäten"
DE["Continue"]="Weiter"
DE["Archive"]="Archiv"
DE["Group details"]="Gruppendetails"

DE["All private categories"]="Alle privaten Kategorien"
DE["Recontact suggestions"]="Wiederkontakt-Vorschläge"
DE["Your private categories:"]="Deine privaten Kategorien:"
DE["Previously observed together in a group."]="Bereits gemeinsam in einer Gruppe beobachtet."
DE["Last together %d days ago."]="Zuletzt gemeinsam vor %d Tagen."
DE["Select a contact to mark. Categories stay private."]="Wähle einen Kontakt zum Markieren. Kategorien bleiben privat."

DE["Private categories use a newer format."]="Private Kategorien verwenden ein neueres Format."
DE["Invalid private category."]="Ungültige private Kategorie."
DE["Select an unblocked contact."]="Wähle einen nicht blockierten Kontakt."
DE["Maximum 1,000 categorized contacts."]="Maximal 1.000 kategorisierte Kontakte."
DE["Contact storage is full."]="Kontaktspeicher ist voll."









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
DE["Saved confirmation; organizer verification is pending."]="Zusage gespeichert; noch keine Bestätigung vom Veranstalter."
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

DE["Craft count is the number of crafting operations."]="Anzahl der Herstellungsvorgänge, unabhängig von der gewünschten Stückzahl."
DE["Offer expires (minutes)"]="Laufzeit (Minuten)"
DE["Min. unit price (gold)"]="Stückpreis ab (Gold)"
DE["Max. unit price (gold)"]="Stückpreis bis (Gold)"


DE["Message (optional)"]="Nachricht (optional)"
DE["Save"]="Speichern"

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
DE["Discover"]="Entdecken"
DE["Organized"]="Organisiert"
DE["Quest applications"]="Quest-Bewerbungen"
DE["Repeat weekly"]="Wöchentlich wiederholen"
DE["Confirming records attendance only. It does not invite anyone to your group."]="Bestätigen vermerkt nur die Teilnahme. Es lädt niemanden in deine Gruppe ein."
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
DE["This link is not supported."]="Dieser Verweis wird nicht unterstützt."
DE["This target is no longer available."]="Dieses Ziel ist nicht mehr verfügbar."
DE["Save or explicitly cancel the unsaved edit first; then open the link again."]="Ungespeicherte Bearbeitung zuerst speichern oder ausdrücklich abbrechen; danach den Verweis erneut öffnen."
DE["Back to Integrations"]="Zurück zu Integrationen"
DE["Connection"]="Verbindung"
DE["Privacy"]="Datenschutz"
DE["Diagnostics and backups"]="Diagnose und Backups"
DE["Open Addon Manager"]="Addon Manager öffnen"
DE["Open Companion"]="Companion öffnen"
DE["Status: "]="Status: "
DE["Account-wide export for all characters, including chat and private notes."]="Accountweiter Export für alle Charaktere, einschließlich Chat und privater Notizen."
DE["Use the bell in the window header for notifications. PvP receiving is controlled in the existing PvP option."]="Nutze die Glocke im Fensterkopf für Benachrichtigungen. Der PvP-Empfang wird über die vorhandene PvP-Option gesteuert."
DE["Map, minimap and slash command entry points remain available."]="Karten-, Minimap- und Slash-Befehl-Einstiege bleiben verfügbar."
DE["Technical details"]="Technische Details"
DE["Hide technical details"]="Technische Details ausblenden"


DE["Disabled"]="Ausgeschaltet"
DE["Export stopped"]="Export angehalten"


DE["Export active"]="Export aktiv"
DE["Account-wide export for all characters, including chat and private notes."]="Accountweiter Export für alle Charaktere, einschließlich Chat und privater Notizen."

-- Translations added with the review fixes
DE["Helpers reached: %d"]="Helfer erreicht: %d"
DE["The start time has already passed."]="Die Startzeit liegt bereits in der Vergangenheit."
DE["The duration must be between 15 and 480 minutes."]="Die Dauer muss zwischen 15 und 480 Minuten liegen."
DE["No more than 40 places in total."]="Insgesamt sind höchstens 40 Plätze möglich."
DE["Only %d free places. Convert the group to a raid to invite more."]="Nur %d freie Plätze. Wandle die Gruppe in einen Schlachtzug um, um mehr einzuladen."
DE["Pixel packets: %d · data lines: %d · timer-origin: %d"]="Pixelpakete: %d · Datenzeilen: %d · davon zeitgesteuert: %d"
DE["Quest areas: "]="Questflächen: "
DE["Pixel strip transmitting."]="Pixelstreifen sendet."
DE["Set up once. Your data appears in your browser or on an external device."]="Einmal einrichten. Deine Daten erscheinen im Browser oder auf einem externen Gerät."
DE["Enable companion export · all data"]="Companion-Export aktivieren · alle Daten"
DE["Export applies to your whole account and every character, including chat and private notes. Categories cannot be enabled separately."]="Export gilt accountweit für alle Charaktere, einschließlich Chat und privater Notizen. Die Kategorien lassen sich nicht einzeln freigeben."
DE["Show quest objective areas · paused in combat"]="Quest-Zielflächen anzeigen · im Kampf pausiert"
DE["Choose events"]="Ereignisse auswählen"
DE["Read only: the browser and external devices execute nothing in the game. Pixels must be visibly rendered. The companion marks data as stale when minimized or reception stops."]="Nur lesend: Browser und externe Geräte führen nichts im Spiel aus. Pixel müssen sichtbar gerendert werden. Bei Minimierung oder fehlendem Empfang zeigt der Companion die Daten als veraltet."
DE["Download companion:"]="Companion herunterladen:"
DE["New in 5.x: your WoW in a browser and on external devices. The companion is optional."]="Neu in 5.x: Dein WoW im Browser und auf externen Geräten. Der Companion ist optional."
DE["Events go to the companion, where they can trigger actions."]="Ereignisse gehen an den Companion und können dort Aktionen auslösen."
DE["Send events"]="Ereignisse übertragen"
DE["ZENIAL Companion · optional"]="ZENIAL Companion · optional"
DE["Read only. Export applies to your whole account, including chat and private notes."]="Nur lesend. Der Export gilt accountweit und umfasst auch Chat und private Notizen."
DE["Enable companion export"]="Companion-Export aktivieren"
DE["Set up companion"]="Companion einrichten"
DE["Death"]="Tod"
DE["Level up"]="Stufenaufstieg"
DE["PvP call for help"]="PvP-Hilferuf"
DE["Enemy defeated"]="Gegner besiegt"
DE["Defeated by enemy"]="Von Gegner besiegt"
DE["Enemy is targeting you"]="Gegner hat dich im Ziel"
DE["Stealthed enemy spotted"]="Getarnter Gegner entdeckt"
DE["Rival nearby"]="Rivale in der Nähe"
DE["Kill"]="Kill"
DE["Killing streak"]="Kill-Serie"
DE["Critical hit"]="Kritischer Treffer"
DE["Proc"]="Proc"
DE["Accept"]="Annehmen"
DE["Mark as ready"]="Als bereit markieren"
DE["Realm correction backup"]="Backup der Realm-Korrektur"
DE["Another search is still running. Click Refresh afterwards."]="Es läuft noch eine andere Suche. Danach auf „Aktualisieren“ klicken."
DE["This order cannot be abandoned locally."]="Dieser Auftrag kann nicht lokal aufgegeben werden."
DE["Give up order"]="Auftrag aufgeben"
DE["Select activity"]="Aktivität auswählen"
DE["Slot %d"]="Slot %d"
DE["Bank"]="Bank"
DE["Material"]="Material"
DE["Kills %d"]="Kills %d"
DE["Watch"]="Watch"
DE["Offer"]="Unbenanntes Angebot"
DE["Right now"]="Gerade jetzt"
DE["Online: %s"]="Online: %s"
DE["ZENIAL Addon"]="ZENIAL-Addon"
DE["Zenial Deck"]="Zenial Deck"

local reverse={}
DE["Find"]="Finden"
DE["My Offers"]="Meine Angebote"
DE["Search alerts"]="Suchalarme"
DE["Create offer"]="Angebot erstellen"
DE["Edit offer"]="Angebot bearbeiten"
DE["← My Offers"]="← Meine Angebote"
DE["Back to crafting"]="Zurück zur Herstellung"
DE["Open in My Offers"]="In Meine Angebote öffnen"
DE["Advanced"]="Erweitert"
DE["Reset"]="Zurücksetzen"
DE["Save search"]="Als Suchalarm speichern"
DE["No additional filters"]="Keine zusätzlichen Filter"
DE["From"]="Ab"
DE["To"]="Bis"
DE["All"]="Alle"
DE["Active"]="Aktiv"
DE["Draft"]="Entwurf"
DE["Paused"]="Pausiert"
DE["Completed offers"]="Beendet"
DE["Templates"]="Vorlagen"
DE["Active offers: %d of 3."]="Aktive Angebote: %d von 3."
DE[" Only three entries can be active; pause, complete, or save one as a draft."]=" Nur drei Einträge können aktiv sein; pausiere oder erledige einen oder speichere ihn als Entwurf."
DE["No active offers."]="Keine aktiven Angebote."
DE["No drafts."]="Keine Entwürfe."
DE["No paused offers."]="Keine pausierten Angebote."
DE["No expired offers."]="Keine abgelaufenen Angebote."
DE["No completed offers."]="Keine abgeschlossenen Angebote."
DE["No templates."]="Keine Vorlagen."
DE[" of 20 search alerts"]=" von 20 Suchalarmen"
DE[". Delete an alert before saving another."]=". Lösche einen Suchalarm, bevor du einen weiteren speicherst."
DE["Alert matches"]="Alarmtreffer"
DE["This offer is closed or withdrawn."]="Dieses Angebot wurde geschlossen oder zurückgezogen."
DE["%s is offline; no current snapshot."]="%s ist offline. Aktuelle Angebotsdaten fehlen."
DE["Offer is no longer in the latest snapshot of %s."]="Bei %s ist dieses Angebot nicht mehr gelistet."
DE["This offer has expired."]="Dieses Angebot ist abgelaufen."
DE["Returning to crafting"]="Zurück zur Herstellung"
local function addReverseTranslations(translations)
    local englishKeys={}
    for english in pairs(translations)do englishKeys[#englishKeys+1]=english end
    table.sort(englishKeys)
    for _,english in ipairs(englishKeys)do
        local deutsch=translations[english]
        if reverse[deutsch]==nil then reverse[deutsch]=english end
    end
end
addReverseTranslations(DE)
addReverseTranslations(ACTIVITY_DE)

-- Keep the tooltip label concise without adding a second reverse translation for "Gilde".
DE["Same guild"]="Gilde"


DE["Shared Quests"]="Gemeinsame Quests"
DE["Help Requests"]="Hilfegesuche"
DE["My Help Request"]="Mein Hilfegesuch"

DE["Your group"]="Deine Gruppe"
DE["In group"]="In Gruppe"
DE["Busy"]="Beschäftigt"
DE["Available"]="Verfügbar"
DE["Find help for this quest"]="Hilfe für diese Quest suchen"

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
DE["Players below have this quest in their last shared quest list. Inviting is separate from a help request."]="Die Spieler unten haben diese Quest laut ihrer zuletzt geteilten Questliste. Einladen ist etwas anderes als eine Hilfsanfrage."
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
DE["Profile data from %s"]="Profildaten von %s"
DE["Saved profile data from %s (player offline)"]="Gespeicherte Profildaten von %s (Spieler offline)"
DE["No profile data received."]="Keine Profildaten empfangen."
DE["Bag contents could not be read. Unknown is not zero."]="Tascheninhalt nicht lesbar. Die Menge ist unbekannt, nicht 0."
DE["Bags read at %s."]="Taschen erfasst um %s."
DE["Bags read just now."]="Taschen gerade erfasst."

DE["Backups"]="Backups"
DE["Delete backup"]="Backup löschen"
DE["Confirm deletion"]="Löschen bestätigen"
DE["No backups stored."]="Keine Backups gespeichert."
DE["Backups are kept until you delete them here. Deleting a backup cannot be undone."]="Backups bleiben erhalten, bis du sie hier löschst. Ein gelöschtes Backup kann nicht wiederhergestellt werden."
DE["Forever Live migration backup"]="Backup der Forever-Live-Migration"
DE["Character migration backup"]="Backup der Charaktermigration"
DE["Merged character profiles backup"]="Backup zusammengeführter Charakterprofile"
-- Social diary
DE["Social diary"]="Begegnungstagebuch"
DE["Private and local. Never shared."]="Privat gespeichert; wird nicht geteilt."

DE["Target"]="Ziel"
DE["Mouseover"]="Mouseover"
DE["Nameplates"]="Namensplaketten"
DE["Filter"]="Filter"
DE["All players"]="Alle Spieler"
DE["Known"]="Bekannt"
DE["With note"]="Mit Notiz"
DE["Grouped together"]="Gemeinsam in Gruppe"
DE["Last encounter"]="Letzte Begegnung"
DE["Most encounters"]="Meiste Begegnungen"
DE["Never observed"]="Nie beobachtet"
DE["Players"]="Spieler"
DE["%d encounters"]="%d Begegnungen"
DE["The social diary uses a newer format."]="Das Begegnungstagebuch nutzt ein neueres Format."
DE["Select a player."]="Wähle einen Spieler."

DE["First contact"]="Erstkontakt"
DE["No recorded encounters."]="Keine erfassten Begegnungen."
DE["Remove known mark"]="Nicht mehr bekannt"
DE["Mark as known"]="Als bekannt markieren"
DE["Remove favorite"]="Favorit entfernen"


DE["Remove from diary"]="Aus Tagebuch entfernen"
DE["Diary entries removed."]="Tagebucheinträge entfernt."
DE["Targeted"]="Als Ziel erfasst"

DE["Dungeon together"]="Gemeinsam im Dungeon"

DE["The social diary is full."]="Das Begegnungstagebuch ist voll."

-- Account overview
DE["Account overview"]="Accountübersicht"
DE["My characters"]="Meine Charaktere"

DE["Record own characters at login"]="Eigene Charaktere beim Login erfassen"
DE["Record bags and opened bank"]="Taschen und geöffnete Bank erfassen"
DE["Faction"]="Fraktion"
DE["Item search"]="Gegenstandssuche"
DE["Characters"]="Charaktere"


DE["Logged in"]="Eingeloggt"
DE["as of %s"]="Stand %s"
DE["Last login"]="Letzter Login"
DE["From ZENIAL Utility"]="Aus ZENIAL Utility"
DE["Only known from the data taken over from ZENIAL Utility. Log in with this character to record more."]="Bisher nur durch den Import aus ZENIAL Utility bekannt. Logge dich mit diesem Charakter ein, um weitere Daten zu erfassen."
DE["Rested XP"]="Erholungsbonus"
DE["Maximum level"]="Höchststufe"
DE["%d%% of a level"]="%d%% einer Stufe"
DE["Resting"]="Erholt sich"
DE["Played time"]="Spielzeit"

DE["%dd %dh"]="%d T %d Std."
DE["%dh %dm"]="%d Std. %d Min."
DE["None recorded"]="Keine erfasst"
DE["%d items"]="%d Gegenstände"
DE["Not recorded"]="Nicht erfasst"
DE["Bank never opened while recording."]="Bankdaten fehlen. Öffne die Bank bei aktiver Erfassung, um sie aufzunehmen."
DE["No matching items in recorded bags and banks."]="Keine passenden Gegenstände in erfassten Taschen und Banken."
DE["%d item names are still loading. Search again in a moment."]="%d Gegenstandsnamen werden noch geladen. Gleich erneut suchen."


DE["The account overview uses a newer format."]="Die Accountübersicht nutzt ein neueres Format."

-- My characters
DE["Neutral"]="Neutral"
DE["Alt"]="Twink"
-- ZENIAL Utility takeover




DE["ZENIAL Utility data taken over %s"]="ZENIAL-Utility-Daten übernommen %s"
DE["%d not assignable"]="%d ohne sichere Zuordnung"
DE["taken over %s"]="übernommen %s"
DE["%d hidden"]="%d ausgeblendet"
DE["Filter active"]="Filter aktiv"
DE["Last recorded gold"]="Zuletzt erfasstes Gold"
DE["Sum of the last recorded values, not live"]="Summe der zuletzt erfassten Werte, nicht live"
DE["no gold recorded for %d"]="ohne Goldstand: %d"
DE["oldest value %s"]="ältester Stand %s"
DE["%d with professions"]="%d mit Berufen"
DE["Recording is off."]="Erfassung ist aus."


DE["hidden"]="ausgeblendet"
DE["Main and alts are set in the game world and faction you are logged in to. Log in there to change this character."]="Main und Twinks werden in der Spielwelt und Fraktion festgelegt, in der du eingeloggt bist. Melde dich dort an, um diesen Charakter zu ändern."
DE["Main of this game world and faction. Without your own choice the first character saved with ZENIAL becomes main; you can change it on any alt."]="Main dieser Spielwelt und Fraktion. Ohne eigene Wahl wird der erste mit ZENIAL gespeicherte Charakter Main; du kannst das an jedem Twink ändern."
DE["Alt of %s. Other members see this link only while your profile is visible."]="Twink von %s. Andere Mitglieder sehen diese Verknüpfung nur, solange dein Profil sichtbar ist."
DE["Hidden from this overview. Its data is kept; show hidden characters to see it again."]="In dieser Übersicht ausgeblendet. Die Daten bleiben erhalten; mit „Ausgeblendete anzeigen“ wieder sichtbar."

DE["Bags and bank are only searched once their recording is on."]="Taschen und Bank werden erst durchsucht, wenn ihre Erfassung eingeschaltet ist."

DE["All matching characters are hidden. Turn on \"Show hidden\" to see them."]="Alle passenden Charaktere sind ausgeblendet. „Ausgeblendete anzeigen“ einschalten, um sie zu sehen."
DE["No character for this realm and faction."]="Kein Charakter für diesen Realm und diese Fraktion."
DE["No characters recorded yet."]="Noch keine Charaktere erfasst."
DE["Show in overview again"]="Wieder in Übersicht anzeigen"
DE["Hide from overview"]="Aus Übersicht ausblenden"
DE["The logged-in character always stays visible and cannot be deleted."]="Der eingeloggte Charakter bleibt immer sichtbar und kann nicht gelöscht werden."
DE["The logged-in character always stays visible."]="Der eingeloggte Charakter bleibt immer sichtbar."
DE["Data can only be deleted for characters of the game world and faction you are logged in to."]="Daten lassen sich nur für Charaktere der Spielwelt und Fraktion löschen, in der du eingeloggt bist."
DE["Delete all data of %s? This removes its saved profile, professions, recipes, drafts and private overview data (gold, rested XP, bags, bank) as well as notes, favorites and categories stored for it. History is kept. If it is your main, the logged-in character becomes main. This cannot be undone."]="Alle Daten von %s löschen? Entfernt werden das gespeicherte Profil, Berufe, Rezepte, Entwürfe und private Übersichtsdaten (Gold, Erholungsbonus, Taschen, Bank) sowie dazu gespeicherte Notizen, Favoriten und Kategorien. Die Historie bleibt erhalten. War er dein Main, wird der eingeloggte Charakter Main. Das lässt sich nicht rückgängig machen."

DE["Show hidden"]="Ausgeblendete anzeigen"
DE["Last updated"]="Zuletzt aktualisiert"

DE["%s is now your main."]="%s ist jetzt dein Main."
DE["Delete character data…"]="Charakterdaten löschen …"
DE["Delete character data"]="Charakterdaten löschen"
DE["Group by main character"]="Nach Hauptcharakter gruppieren"
DE["Offline"]="Offline"
DE["playing main"]="spielt Main"
DE["Online · playing %s"]="Online · spielt %s"
DE["Offline · last seen %s"]="Offline · zuletzt gesehen %s"
DE["+%d more online"]="+%d weitere online"
DE["%d known character"]="%d bekannter Charakter"
DE["%d known characters"]="%d bekannte Charaktere"
DE["not seen yet"]="noch nicht gesehen"
DE["No character online"]="Kein Charakter online"
DE["Acts on"]="Wirkt auf"
DE["Online: %s - select the row to contact"]="Online: %s - Zeile wählen zum Kontaktieren"
DE["Contact: %s"]="Kontakt: %s"
DE["Invitation submitted to %s; awaiting response."]="Einladung an %s angefordert; warte auf Antwort."
DE["Known characters"]="Bekannte Charaktere"
DE["+%d more characters"]="+%d weitere Charaktere"


DE["%d player"]="%d Spieler"
DE["%d players"]="%d Spieler"
DE["%d character"]="%d Charakter"
DE["%d characters"]="%d Charaktere"
DE["Match"]="Treffer"
DE["%s has not been seen with ZENIAL yet."]="ZENIAL hat %s noch nicht erfasst."
DE["Main and alts as declared by their addon; not verified."]="Hauptcharakter und Twinks laut Addon; nicht geprüft."



-- My characters: sheet layout, tabs, saved items and recording options
DE["Stored privately"]="Privat gespeichert"

DE["Overview"]="Übersicht"
DE["Inventory search"]="Inventarsuche"
DE["Search the recorded bags and bank compartments of your characters."]="Durchsuche aufgezeichnete Taschen und Bankfächer deiner Charaktere."
DE["Bag and bank recording must be on. Bank contents exist only after you opened the bank while recording. Saved amounts can be older than your current inventory."]="Aktiviere die Erfassung von Taschen und Bank. Bankbestände werden nur aufgenommen, wenn du die Bank bei aktiver Erfassung öffnest. Gespeicherte Mengen können veraltet sein."
DE["%d characters · Bags %d · Bank %d"]="%d Charaktere · Taschen %d · Bank %d"
DE["Private for %s"]="Privat für %s"
DE["Advanced"]="Erweitert"
DE["Quick filter"]="Schnellfilter"

DE["Public profile: current character"]="Öffentliches Profil: aktueller Charakter"
DE["Search character"]="Charakter suchen"
DE["Back to results"]="Zurück zu Ergebnissen"
DE["More"]="Mehr"
DE["Recording options"]="Aufnahmeoptionen"
DE["GOLD"]="GOLD"


DE["PROFESSIONS"]="BERUFE"
DE["BAGS"]="TASCHEN"
DE["BANK"]="BANK"
DE["on"]="an"
DE["off"]="aus"
DE["Recording: %s · Bags and bank: %s"]="Aufnahme: %s · Taschen und Bank: %s"
DE["Turning recording off only stops new entries. Saved data is not deleted."]="Wenn die Aufnahme aus ist, werden nur keine neuen Daten erfasst. Gespeicherte Daten werden nicht gelöscht."
DE["No character matches this search."]="Kein Charakter passt zu dieser Suche."
DE["Item name (2+ characters) or item ID"]="Gegenstandsname (mind. 2 Zeichen) oder Gegenstands-ID"
DE["Scope: %s"]="Bereich: %s"
DE["All realms"]="Alle Realms"
DE["All factions"]="Alle Fraktionen"
DE["including hidden"]="inkl. ausgeblendete"
DE["Enter an item name with at least 2 characters or an item ID to search recorded bags and banks."]="Gib einen Gegenstandsnamen mit mindestens 2 Zeichen oder eine Gegenstands-ID ein, um erfasste Taschen und Banken zu durchsuchen."
DE["Select an item to see which characters hold it."]="Wähle einen Gegenstand, um zu sehen, welche Charaktere ihn haben."
-- My characters 2.0: tabs, character cards and details
DE["Inventory"]="Inventar"
DE["No professions recorded"]="Keine Berufe erfasst"
DE["Primary professions"]="Hauptberufe"
DE["Secondary professions"]="Nebenberufe"
DE["Gold"]="Gold"
DE["XP"]="EP"
DE["Data"]="Daten"
DE["Bags and bank"]="Taschen und Bank"
DE["%d of %d slots used"]="%d von %d Plätzen belegt"
DE["1 recipe"]="1 Rezept"
DE["%d recipes"]="%d Rezepte"

-- Visual overhaul: sidebar groups and page subtitles.
DE["Play"]="Spielen"
DE["Economy"]="Wirtschaft"
DE["Find fellow players, keep notes and stay in touch"]="Mitspieler finden, Notizen führen und in Kontakt bleiben"
DE["Recipes, crafting orders and shopping lists"]="Rezepte, Herstellungsaufträge und Einkaufslisten"
DE["Groups, events and PvP help from the community"]="Gruppen, Termine und PvP-Hilfe aus der Community"
DE["Shared quests, quest groups and help requests"]="Gemeinsame Quests, Questgruppen und Hilfegesuche"
DE["Offers, requests and search alerts"]="Angebote, Gesuche und Suchalarme"
DE["Your characters, public profile and item search"]="Deine Charaktere, dein öffentliches Profil und die Gegenstandssuche"
DE["Past contacts and requests"]="Vergangene Kontakte und Anfragen"
DE["Settings of your installed ZENIAL addons"]="Einstellungen deiner installierten ZENIAL-Addons"

DE["Display, privacy, tools and data"]="Darstellung, Privatsphäre, Werkzeuge und Daten"
DE["Players you were in a group with appear here automatically."]="Spieler, mit denen du in einer Gruppe warst, erscheinen hier automatisch."
-- English display copy is separate from stable source keys and stored values.
-- Group finder (UXFinder.lua, GroupFinderCatalog.lua).
DE["More options"]="Weitere Angaben"
DE["optional: level, size, classes, comment"]="optional: Level, Größe, Klassen, Kommentar"
DE["Preferred classes"]="Bevorzugte Klassen"
DE["No selection: every class is welcome"]="Keine Auswahl: jede Klasse ist willkommen"
DE["Preferred: %s"]="Bevorzugt: %s"
DE["You play %s"]="Du spielst %s"
-- Quest request and scheduled event forms (ActivityFormsUI.lua).
DE["Quest help or levelling together"]="Questhilfe oder gemeinsames Leveln"
DE["The request stays open for %d minutes."]="Die Anfrage bleibt %d Minuten offen."
DE["optional: zone, level, duration, comment"]="optional: Zone, Level, Laufzeit, Kommentar"
DE["What do you need help with?"]="Wobei brauchst du Hilfe?"
DE["Others can sign up once the event is published."]="Andere können sich anmelden, sobald der Termin veröffentlicht ist."
DE["Date or time is not valid"]="Datum oder Uhrzeit ist ungültig"
DE["%d places wanted"]="%d Plätze gesucht"
DE["optional: duration, comment"]="optional: Laufzeit, Kommentar"
DE["carried on, not yet confirmed"]="weitergetragen, noch nicht bestätigt"
DE["Left with a participant"]="Bei Teilnehmer hinterlegt"
DE["Left with a participant; the organizer has not seen it yet"]="Bei einem Teilnehmer hinterlegt; der Ersteller hat es noch nicht gesehen"
DE["Carried on; not yet confirmed by the organizer"]="Weitergetragen, vom Ersteller noch nicht bestätigt"
DE["Handed over by %s"]="Überbracht von %s"
DE["This event is not open for applications right now."]="Dieser Termin nimmt gerade keine Anmeldungen an."
DE["Organizer offline"]="Ersteller offline"
DE["Start"]="Start"
DE["Who is online and what is open in the community right now"]="Wer online ist und was in der Community gerade offen ist"
DE["Members online"]="Mitglieder online"
DE["Planned groups"]="Geplante Gruppen"
DE["Requests waiting for you"]="Anfragen an dich"
DE["Your open requests"]="Deine offenen Anfragen"
DE["In demand right now"]="Gerade gefragt"

DE["Stays open until you go offline."]="Bleibt offen, bis du offline gehst."
DE["Wanted roles"]="Gesuchte Rollen"
DE["%d of %d places wanted"]="%d von %d Plätzen gesucht"
DE["you are alone"]="du bist allein"
DE["1 quest in common"]="1 gemeinsame Quest"
DE["Players with quests in common"]="Spieler mit gemeinsamen Quests"
DE["Switch it on under Settings, Privacy, to see who has the same quests."]="Schalte sie unter Einstellungen, Datenschutz, ein, um zu sehen, wer dieselben Quests hat."
DE["Nobody online shares one of your quests right now."]="Gerade teilt niemand, der online ist, eine deiner Quests."
DE["You can look for at most 3 activities at once."]="Du kannst höchstens 3 Aktivitäten gleichzeitig suchen."
DE["Only dungeons, raids and battlegrounds can be combined in a search."]="Nur Dungeons, Raids und Schlachtfelder lassen sich in einer Suche kombinieren."
DE["You are not looking for a group."]="Du suchst gerade keine Gruppe."
DE["1 more instance"]="1 weitere Instanz"
DE["%d more instances"]="%d weitere Instanzen"
DE["Stop looking here"]="Hier nicht mehr suchen"
DE["Look here too (%d/%d)"]="Auch hier suchen (%d/%d)"
DE["Looking for a group"]="Gruppensuche"
DE["%s added to your search (%d/%d)."]="%s zur Suche hinzugefügt (%d/%d)."
DE["%s removed from your search."]="%s aus der Suche entfernt."
DE["Live"]="Aktuell"
DE["Questing and levelling"]="Questen"
DE["Levelling"]="Questen"
DE["Requests"]="Anfragen"
DE["1 group"]="1 Gruppe"
DE["%d groups"]="%d Gruppen"
DE["1 looking"]="1 sucht"
DE["%d looking"]="%d suchen"
DE["1 planned"]="1 geplant"
DE["%d planned"]="%d geplant"
DE["Level %d"]="Level %d"
DE["Level %d–%d"]="Level %d–%d"
DE["Figures from the ZENIAL community"]="Zahlen aus der ZENIAL-Community"
DE["Your search"]="Deine Suche"
DE["New"]="Neu"
DE["Group is full"]="Gruppe ist voll"
DE["Request pending"]="Anfrage offen"
DE["In the group"]="In der Gruppe"
DE["Confirmed"]="Bestätigt"
DE["Looking for: %s"]="Sucht: %s"
DE["Roles"]="Rollen"
DE["Stop search"]="Suche beenden"

DE["%d/%d players"]="%d/%d Spieler"
DE["Requests (%d)"]="Anfragen (%d)"
DE["Full"]="Voll"
DE["Request to join"]="Beitritt anfragen"
DE["Your event"]="Dein Termin"
DE["Sign off"]="Abmelden"
DE["Sign up"]="Anmelden"
DE["Your role"]="Deine Rolle"
DE["You are now looking for a group for %s."]="Du suchst jetzt eine Gruppe für %s."
DE["Search ended."]="Suche beendet."
DE["You will be notified about new groups for %s."]="Du wirst über neue Gruppen für %s benachrichtigt."
DE["The Dungeon Journal has no page for this instance yet."]="Das Dungeon Journal hat für diese Instanz noch keine Seite."
DE["The Dungeon Journal could not be opened."]="Das Dungeon Journal konnte nicht geöffnet werden."
DE["No instance matches"]="Keine passende Instanz"
DE["Change the filters or the search text."]="Ändere die Filter oder den Suchtext."
DE["%d dungeons"]="%d Dungeons"
DE["%d raids"]="%d Raids"
DE["%d battlegrounds"]="%d Schlachtfelder"
DE["Nothing is open in the ZENIAL community right now. Create a group, or pick an instance under Dungeons and look for one."]="In der ZENIAL-Community ist gerade nichts offen. Erstelle eine Gruppe oder wähle unter Dungeons eine Instanz und suche dort eine."
DE["Open groups"]="Offene Gruppen"
DE["Players looking for a group"]="Spieler suchen eine Gruppe"
DE["Nobody with this role is looking right now."]="Niemand mit dieser Rolle sucht gerade."
DE["Quest and PvP help"]="Quest- und PvP-Hilfe"
DE["Nobody asks for quest help right now."]="Gerade bittet niemand um Questhilfe."
DE["No questing or levelling group is open."]="Keine Quest- oder Levelgruppe offen."
DE["No other group is open."]="Keine weitere Gruppe offen."
DE["open"]="offen"
DE["in the ZENIAL community"]="in der ZENIAL-Community"
DE["Manage my group"]="Meine Gruppe verwalten"
DE["I am looking for a group"]="Ich suche eine Gruppe"
DE["No group is open for this instance. Create one, or look for a group and let others find you."]="Für diese Instanz ist keine Gruppe offen. Erstelle eine oder suche eine Gruppe, damit andere dich finden."
DE["Nobody is looking for this instance right now."]="Gerade sucht niemand für diese Instanz."


DE["Close group"]="Gruppe schließen"
DE["My search"]="Meine Suche"

DE["Show instance"]="Instanz anzeigen"
DE["My requests"]="Meine Anfragen"
DE["1 request is waiting for an answer."]="1 Anfrage wartet auf Antwort."
DE["%d requests are waiting for an answer."]="%d Anfragen warten auf Antwort."
DE["Show requests"]="Anfragen anzeigen"
DE["My level"]="Mein Level"
DE["Players looking"]="Suchende"
DE["Search instance"]="Instanz suchen"
DE["Open PvP Help"]="PvP-Hilfe öffnen"
DE["Back to overview"]="Zur Übersicht"

DE["Open Dungeon Journal"]="Dungeon Journal öffnen"
DE["My roles"]="Meine Rollen"
DE["Start search"]="Suche starten"

DE["List view"]="Listenansicht"
DE["Tile view"]="Kachelansicht"
DE["Close your group before you look for one."]="Schließe zuerst deine Gruppe, bevor du eine suchst."
DE["Choose at least one role."]="Wähle mindestens eine Rolle."
-- Public group search of the game inside the group finder (UXFinderPublic.lua).
DE["Public"]="Öffentlich"
DE["Public groups"]="Öffentliche Gruppen"
DE["Unknown player"]="Unbekannter Spieler"
DE["listed for %d s"]="seit %d Sek. gelistet"
DE["listed for %d min"]="seit %d Min. gelistet"
DE["listed for %d h"]="seit %d Std. gelistet"
DE["Roles unknown"]="Rollen unbekannt"
DE["Role needs unknown"]="Rollenbedarf unbekannt"
DE["No longer listed"]="Nicht mehr verfügbar"
DE["Inviting is unavailable."]="Einladen ist nicht verfügbar."
DE["Searching public groups …"]="Suche öffentliche Gruppen …"
DE["The group search did not answer. Try again."]="Die Gruppensuche hat nicht geantwortet. Bitte erneut versuchen."
DE["The group search failed. Try again."]="Die Gruppensuche ist fehlgeschlagen. Bitte erneut versuchen."
DE["The game refused the search."]="Das Spiel hat die Suche abgelehnt."
DE["The group search of the game offers nothing here."]="Die Gruppensuche des Spiels bietet hier nichts an."
DE["Not possible in combat."]="Im Kampf nicht möglich."
DE["Not possible right now."]="Gerade nicht möglich."
DE["Possible again in a moment."]="Gleich wieder möglich."
DE["Choose at least one language."]="Wähle mindestens eine Sprache."
DE["Public: %s"]="Öffentlich: %s"
DE["Public sample: %s"]="Öffentlich (Stichprobe): %s"
DE["as of %s"]="Stand %s"
DE["%d public"]="%d öffentlich"
DE["%d+ public"]="%d+ öffentlich"
DE["No public group is listed right now."]="Gerade ist keine öffentliche Gruppe gelistet."
DE["Load the public groups to see what is listed in the game."]="Lade die öffentlichen Gruppen, um zu sehen, was im Spiel gelistet ist."
DE["Show public groups of the game in the group finder"]="Öffentliche Gruppen des Spiels im Gruppenfinder anzeigen"
DE["Public groups of the game are shown in the group finder."]="Öffentliche Gruppen des Spiels werden im Gruppenfinder angezeigt."
DE["Public groups of the game are hidden."]="Öffentliche Gruppen des Spiels sind ausgeblendet."
DE["Only fitting"]="Nur passende"
DE["Languages of the public search"]="Sprachen der öffentlichen Suche"
DE["Game default"]="Standard"
DE["Selection"]="Auswahl"
DE["Very fitting"]="Sehr passend"
DE["Fitting"]="Passend"
DE["Role unknown"]="Rolle unbekannt"
DE["ZENIAL member"]="ZENIAL-Mitglied"
DE["Friend in the group"]="Freund in der Gruppe"
DE["Guild member in the group"]="Gildenmitglied in der Gruppe"
DE["You wrote to this leader a short while ago."]="Du hast diesen Gruppenleiter vor kurzem angeschrieben."
DE["This listing is no longer available."]="Dieser Eintrag ist nicht mehr verfügbar."
DE["The name of the leader is not known yet."]="Der Name des Gruppenleiters ist noch nicht bekannt."
DE["The chat box is ready. Press Enter to send."]="Das Chatfeld ist vorbereitet. Drücke Enter zum Senden."
DE["Chat opened"]="Chat geöffnet"
DE["Message sent"]="Nachricht gesendet"
DE["Contact fitting groups (%d)"]="Passende Gruppen kontaktieren (%d)"
DE["Contact fitting groups: %s"]="Passende Gruppen kontaktieren: %s"
DE["Message to public groups"]="Nachricht an öffentliche Gruppen"
-- Whisper texts (WhisperTexts.lua, UXWhisperDesigner.lua).
DE["Whisper · %s"]="Anflüstern · %s"
DE["Edit texts…"]="Texte bearbeiten…"
DE["Texts"]="Texte"
DE["To groups"]="An Gruppen"
DE["To players"]="An Spieler"
DE["New text"]="Neuer Text"
DE["Text"]="Text"
DE["Insert"]="Einfügen"
DE["Language of values"]="Sprache der Werte"
DE["Too long: the end is cut off."]="Zu lang: Das Ende wird abgeschnitten."
DE["My name"]="Mein Name"
DE["Leader"]="Leader"
DE["This text is empty."]="Dieser Text ist leer."
DE["Skip"]="Überspringen"
DE["Start (%d)"]="Starten (%d)"
DE["Group %d of %d"]="Gruppe %d von %d"
DE["No group fits right now, or you already contacted them all."]="Gerade passt keine Gruppe, oder du hast alle schon kontaktiert."
DE["Pick the groups to contact. Each one is contacted with one click of yours, one after the other."]="Wähle die Gruppen aus. Jede wird einzeln mit einem Klick von dir kontaktiert."
DE["Choose your role and send the join request."]="Wähle deine Rolle und sende die Beitrittsanfrage."
DE["Press Enter in the chat to send your message. Then go on."]="Drücke im Chat Enter, um die Nachricht zu senden. Dann geht es weiter."
DE["The chat box opens with your message. You send it with Enter."]="Das Chatfeld öffnet sich mit deiner Nachricht. Du sendest sie mit Enter."
DE["Message sent."]="Nachricht gesendet."
DE["Prepare message"]="Nachricht vorbereiten"
DE["Next group"]="Nächste Gruppe"
DE["Finish"]="Fertig"
DE["Done. 1 group contacted."]="Fertig. 1 Gruppe kontaktiert."
DE["Done. %d groups contacted."]="Fertig. %d Gruppen kontaktiert."
DE["You are in a group now."]="Du bist jetzt in einer Gruppe."
DE["The group search of the game does not know this activity."]="Die Gruppensuche des Spiels kennt diese Aktivität nicht."
DE["These are too many activities for one public listing."]="Das sind zu viele Aktivitäten für einen öffentlichen Eintrag."
DE["Only the leader can list the group publicly."]="Nur der Gruppenleiter kann die Gruppe öffentlich listen."
DE["Your group is already full."]="Deine Gruppe ist bereits voll."
DE["The game refused the public listing."]="Das Spiel hat den öffentlichen Eintrag abgelehnt."
DE["The public listing failed."]="Der öffentliche Eintrag ist fehlgeschlagen."
DE["The public listing is unavailable."]="Der öffentliche Eintrag ist nicht verfügbar."
DE["Your public listing was removed."]="Dein öffentlicher Eintrag wurde entfernt."
DE["Listed publicly. Your note is not shown there."]="Öffentlich gelistet. Deine Notiz erscheint dort nicht."
DE["Public listing"]="Öffentlicher Eintrag"
DE["Others find your group in the group search of the game and whisper you. Your note is not shown there."]="Andere finden deine Gruppe in der Gruppensuche des Spiels und flüstern dich an. Deine Notiz erscheint dort nicht."
DE["Without a group you appear there as a single player."]="Ohne Gruppe erscheinst du dort als einzelner Spieler."
DE["The game ends a public listing after 30 minutes."]="Das Spiel beendet einen öffentlichen Eintrag nach 30 Minuten."
DE["List publicly"]="Öffentlich listen"
DE["Listing publicly …"]="Wird gelistet …"
DE["Listed publicly"]="Öffentlich gelistet"
DE["Public listing differs"]="Öffentlich: weicht ab"
DE["List publicly again"]="Erneut listen"
DE["Updated just now"]="Gerade aktualisiert"
DE["Updated %d seconds ago"]="Aktualisiert vor %d Sekunden"
DE["Updated 1 minute ago"]="Aktualisiert vor 1 Minute"
DE["Updated %d minutes ago"]="Aktualisiert vor %d Minuten"
DE["only part of the entries"]="nur ein Teil der Einträge"
DE["Public groups are not loaded yet."]="Öffentliche Gruppen sind noch nicht geladen."
DE["Language changed. Refresh to search again."]="Sprache geändert. Aktualisieren sucht neu."
DE["Role: %s"]="Rolle: %s"
DE["Language: %s"]="Sprache: %s"
DE["%d languages"]="%d Sprachen"
DE["No choice: your role comes from your profile or from the game."]="Keine Auswahl: Deine Rolle kommt aus deinem Profil oder aus dem Spiel."
DE["Searches the group search of the game again for what you see here."]="Durchsucht die Gruppensuche des Spiels erneut für das, was du hier siehst."
DE["Opening an instance searches by itself."]="Beim Öffnen einer Instanz wird von selbst gesucht."
DE["The game returns at most 100 entries."]="Das Spiel liefert höchstens 100 Einträge."
DE["Public group"]="Öffentliche Gruppe"
DE["Refresh to see the members."]="Aktualisieren zeigt die Mitglieder."
DE["in the group search of the game"]="in der Gruppensuche des Spiels"
DE["ZENIAL and public"]="ZENIAL und öffentlich"
DE["or"]="oder"
DE["The group search of the game shows the activity, your members and the play style. Level, preferred classes and comment are seen by ZENIAL members only."]="Die Gruppensuche des Spiels zeigt die Aktivität, deine Mitglieder und den Spielstil. Level, bevorzugte Klassen und Kommentar sehen nur ZENIAL-Mitglieder."
DE["New players welcome"]="Neue Spieler willkommen"
DE["Area unknown"]="Gebiet unbekannt"
DE["Location: %s"]="Standort: %s"
DE["Group leader: %s"]="Gruppenleiter: %s"
DE["In the dungeon area"]="Im Dungeon-Gebiet"
DE["In the area of the activity"]="Im Gebiet der Aktivität"
DE["Show a pop-up for new groups of instances you follow"]="Hinweisfenster bei neuen Gruppen gefolgter Instanzen zeigen"
DE["Carry offered"]="Beförderung angeboten"
DE["Competitive"]="Kompetitiv"
DE["Relaxed"]="Entspannt"
DE["Learning"]="Lernen"
DE["Notify me about new ZENIAL groups for this instance"]="Bei neuer ZENIAL-Gruppe für diese Instanz benachrichtigen"
DE["You are notified about new ZENIAL groups for this instance. Click to stop."]="Du wirst bei neuen ZENIAL-Gruppen für diese Instanz benachrichtigt. Klicken beendet das."
DE["%d+"]="ab %d"
DE["Save profile"]="Profil speichern"
DE["Profile saved."]="Profil gespeichert."
DE["Public group search"]="Öffentliche Gruppensuche"
DE["Contact fitting groups"]="Passende Gruppen kontaktieren"
DE["Shown groups"]="Angezeigte Gruppen"
DE["ZENIAL: groups of ZENIAL members. You apply with a click."]="ZENIAL: Gruppen von ZENIAL-Mitgliedern. Du bewirbst dich mit einem Klick."
DE["Public: groups from the group search of the game. You whisper their leader."]="Öffentlich: Gruppen aus der Gruppensuche des Spiels. Du flüsterst die Leitung an."
DE["Very fitting: only your role is missing, or tank and healer are already there."]="Sehr passend: Nur deine Rolle fehlt noch, oder Tank und Heiler sind schon da."
DE["Fitting: there is a place for one of your roles."]="Passend: Für eine deiner Rollen ist ein Platz frei."
DE["Role unknown: the game does not tell which roles are missing."]="Rolle unbekannt: Das Spiel nennt nicht, welche Rollen fehlen."
DE["Groups without a place for you and full groups are hidden."]="Gruppen ohne Platz für dich und volle Gruppen werden ausgeblendet."
DE["Goes through the groups that fit you, one at a time. You confirm every contact with a click."]="Geht die passenden Gruppen einzeln durch. Jeden Kontakt bestätigst du mit einem Klick."

DE["Notices for new groups of followed activities are on."]="Hinweise auf neue Gruppen beobachteter Aktivitäten sind an."
DE["Notices for new groups of followed activities are off. They stay in the bell."]="Hinweise auf neue Gruppen beobachteter Aktivitäten sind aus. In der Glocke bleiben sie sichtbar."
DE["Tirisfal Glades"]="Tirisfal"
DE["Wetlands"]="Sumpfland"
DE["Alterac Mountains"]="Alteracgebirge"
DE["Stranglethorn Vale"]="Schlingendorntal"
DE["Dustwallow Marsh"]="Marschen von Dustwallow"
DE["Un'Goro Crater"]="Krater von Un'Goro"
DE["The Barrens"]="Brachland"
DE["Silverpine Forest"]="Silberwald"
DE["Ashenvale"]="Eschental"
DE["Stormwind City"]="Sturmwind"
DE["Badlands"]="Ödland"
DE["Swamp of Sorrows"]="Sümpfe des Elends"
DE["Blackrock Mountain"]="Der Schwarzfels"
DE["Western Plaguelands"]="Westliche Pestländer"
DE["Eastern Plaguelands"]="Östliche Pestländer"
DE["Mount Hyjal"]="Hyjal"
DE["Arathi Highlands"]="Arathihochland"

local EN={
    ["%d not assignable"]="%d could not be matched safely",
    ["%s has not been seen with ZENIAL yet."]="ZENIAL has not recorded %s yet.",
    ["%s is offline; no current snapshot."]="%s is offline. Offer data may be out of date.",
    ["Bag and bank recording must be on. Bank contents exist only after you opened the bank while recording. Saved amounts can be older than your current inventory."]="Turn on bag and bank recording. Bank data is saved only when you open the bank while recording. Saved amounts may be out of date.",
    ["Bag contents could not be read. Unknown is not zero."]="Bag contents could not be read, so the quantity is unknown—not zero.",
    ["Bags only; oldest active list reserves first."]="Bag stock is shared between lists; older lists take priority.",
    ["Bags read at %s."]="Bags last checked: %s.",
    ["Bags read just now."]="Bags checked just now.",
    ["Bank never opened while recording."]="No bank data saved. Open the bank while recording is on to capture it.",
    ["Choose one to four upcoming instances."]="Choose 1 to 4 upcoming dates.",
    ["Crafts for material planning"]="Number of crafts",
    ["Crafts to plan"]="Number of crafts",
    ["Ingredient list completeness is unverified."]="This ingredient list may be incomplete.",
    ["Local time conversion is unavailable or this clock time does not exist. Use an explicit UTC time."]="That local time is invalid or unavailable. Enter a UTC time instead.",
    ["Local time conversion is unavailable."]="This local time cannot be converted.",
    ["Main and alts as declared by their addon; not verified."]="Main and alt links are reported by the addon and have not been verified.",
    ["Manual marks do not confirm inventory or handoff."]="Checked items are not proof of ownership or delivery.",
    ["Nothing stored locally. Drafts, templates and finished offers appear after you create an offer."]="No offers saved yet. Drafts, templates, and completed offers will appear here.",
    ["Number of instances"]="Number of dates",
    ["Offer is no longer in the latest snapshot of %s."]="This offer is no longer listed in %s's latest data.",
    ["Only known from the data taken over from ZENIAL Utility. Log in with this character to record more."]="This character's data was imported from ZENIAL Utility. Log in as this character to record more.",
    ["Organizer offline or not directly reachable"]="The organizer is offline or cannot be contacted right now.",
    ["Private and local. Never shared."]="Stored on this computer. Never shared.",
    ["Queued operation"]="Action queued",
    ["Reported online; not directly reachable"]="Reported online, but no direct connection is available.",
    ["Same guild"]="Guild",
    ["Saved confirmation; organizer verification is pending."]="Your response is saved, but the organizer has not confirmed it yet.",
    ["Saved material plans use an unsupported version. Data was preserved."]="These shopping lists use an unsupported version. They were kept unchanged.",
    ["Saved scheduled groups are unavailable. Data was preserved."]="Saved events could not be read. Your data was kept.",
    ["Saved state; verification pending"]="Saved status; not checked with the organizer yet.",
    ["Scheduled revision limit reached."]="Too many changes to this event.",
    ["Set craft count explicitly; recipe yield is unknown."]="Enter how many crafts you want. Recipe yield is unknown.",
    ["Shopping list storage is full (100 lists)."]="You can save up to 100 shopping lists.",
    ["Status transfer unknown"]="Delivery status unknown",
    ["Verification in progress"]="Checking with the organizer…",
    ["Weekly instances: same organizer local time"]="Weekly, at the organizer's local time.",
    ["Withdraw and verify an active application before forgetting it."]="Withdraw your active application and check its status before removing it.",
}

local I={locale=locale,isGerman=german,strings=DE,activities=ACTIVITY_DE}
local function atomic(value)
    local english=reverse[value]or value
    if german then return DE[english]or ACTIVITY_DE[english]or english end
    return EN[english]or english
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
-- An extra activity of the group finder (PublicLFGMap) has no entry here: the client names it in its own language.
function I.Activity(value)
    local id=Z.Logic and Z.Logic.ActivityID(value)or value
    local extra=Z.PublicLFGMap and not ACTIVITY_DE[id]and Z.PublicLFGMap.ExtraName(id)
    if extra then return extra end
    return german and(ACTIVITY_DE[id]or id)or id or""
end
local CLASS_EN={WARRIOR="Warrior",PALADIN="Paladin",HUNTER="Hunter",ROGUE="Rogue",PRIEST="Priest",SHAMAN="Shaman",MAGE="Mage",WARLOCK="Warlock",DRUID="Druid"}
function I.Class(value,token)
    local id=token or value;local english=CLASS_EN[id]
    if not english then return value or I.Text("Unknown")end
    return german and(Z.Logic.CLASS_DE[id]or english)or english
end
-- Names in a given language ('de' or 'en'), whatever the language of the client: for texts to other players.
function I.ClassIn(language,classFile)
    local english=CLASS_EN[classFile];if not english then return nil end
    return language=="de"and(Z.Logic.CLASS_DE[classFile]or english)or english
end
function I.ActivityIn(language,value)
    local id=Z.Logic and Z.Logic.ActivityID(value)or value
    if type(id)~="string"or id==""then return nil end
    if ACTIVITY_DE[id]then return language=="de"and ACTIVITY_DE[id]or id end
    return Z.PublicLFGMap and Z.PublicLFGMap.ExtraName(id)or id
end

Z.Locale=I
Z.T=function(value,...)return I.Format(value,...)end

DE["Integrations"]="Integrationen"
DE["History and categories"]="Verlauf und Kategorien"
DE["Connection and privacy"]="Datenschutz und Verbindung"
DE["Stored only on this computer. This list itself is not sent to other players. While your public profile is visible, your main character and up to 10 other characters of the same realm and faction are published with it. The optional Companion export is a separate setting."]="Nur auf diesem Computer gespeichert. Diese Liste selbst wird nicht an andere Spieler gesendet. Solange dein öffentliches Profil sichtbar ist, werden dein Hauptcharakter und bis zu 10 weitere Charaktere desselben Realms und derselben Fraktion mitveröffentlicht. Der optionale Companion-Export ist eine separate Einstellung."
DE["While your public profile is visible, other players can see your main character and up to 10 other characters of this realm and faction."]="Solange dein öffentliches Profil sichtbar ist, können andere Spieler deinen Hauptcharakter und bis zu 10 weitere Charaktere dieses Realms und dieser Fraktion sehen."
DE["When enabled, your display name, class, level, guild, roles, note, group listing, quest request, trade offers, main and alts are shared with other players. Professions and recipes are shared only when the second setting is enabled. When disabled, those details are omitted. Character name, realm, faction, online presence and PvP receiving marker remain visible."]="Wenn diese Option aktiv ist, werden Anzeigename, Klasse, Stufe, Gilde, Rollen, Notiz, Gruppensuche, Questanfrage, Handelsangebote sowie Hauptcharakter und Twinks mit anderen Spielern geteilt. Berufe und Rezepte werden nur geteilt, wenn auch die zweite Option aktiv ist. Ist diese Option aus, entfallen diese Angaben. Charaktername, Realm, Fraktion, Online-Präsenz und der PvP-Empfangsmarker bleiben sichtbar."
DE["The note is too long to keep in the return context. Shorten the note before opening this offer."]="Die Notiz ist zu lang für den Rückkehrkontext. Kürze die Notiz, bevor du dieses Angebot öffnest."
DE["Share detected PvP combat data"]="Erkannte PvP-Kampfdaten mitsenden"
DE["%s – PvP death"]="%s – PvP-Tod"
DE["Died less than a minute ago"]="Vor weniger als einer Minute gestorben"
DE["Died %d min ago"]="Vor %d Minuten gestorben"
DE["Killer: %s"]="Killer: %s"
DE["Further attackers (at least %d)"]="Weitere Angreifer (mindestens %d)"
DE["Level unknown"]="Level unbekannt"
DE["PvP deaths"]="PvP-Tode"
DE["Kill log shortened"]="Kill-Log gekürzt"
DE["No confirmed PvP combat data detected."]="Keine bestätigten PvP-Kampfdaten erkannt."
DE["Attackers (at least %d)"]="Angreifer (mindestens %d)"
DE["ZENIAL: the message was sent, but its own echo was not seen. Others may not have received it."]="ZENIAL: Die Nachricht wurde gesendet, aber das eigene Echo kam nicht an. Andere haben sie möglicherweise nicht erhalten."
DE["ZENIAL: message from %s received incompletely."]="ZENIAL: Nachricht von %s unvollständig empfangen."
DE["ZENIAL: %s is already used by another addon. Use %s instead."]="ZENIAL: %s ist bereits von einem anderen Addon belegt. Nutze stattdessen %s."
DE["ZENIAL: Usage: %s <text>"]="ZENIAL: Benutzung: %s <Text>"
DE["ZENIAL: Cross-faction chat is turned off. Turn it on in the ZENIAL Community settings (option \"Enable cross-faction chat\")."]="ZENIAL: Der Cross-Faction-Chat ist ausgeschaltet. Einschalten unter Einstellungen von ZENIAL Community (Option „Cross-Faction-Chat aktivieren“)."
DE["ZENIAL: The message is %d characters too long (at most %d bytes). Nothing was sent."]="ZENIAL: Die Nachricht ist um %d Zeichen zu lang (höchstens %d Byte). Es wurde nichts gesendet."
DE["ZENIAL: The text contains characters that cannot be displayed. Nothing was sent."]="ZENIAL: Der Text enthält nicht darstellbare Zeichen. Es wurde nichts gesendet."
DE["ZENIAL: Too many messages in a short time. Please wait a moment."]="ZENIAL: Zu viele Nachrichten in kurzer Zeit. Bitte kurz warten."
DE["ZENIAL: Chat is currently locked. Nothing was sent."]="ZENIAL: Der Chat ist gerade gesperrt. Es wurde nichts gesendet."
DE["ZENIAL: The game client blocked sending. Nothing was sent."]="ZENIAL: Der Client hat das Senden blockiert. Es wurde nichts gesendet."
DE["ZENIAL: Sending failed."]="ZENIAL: Senden fehlgeschlagen."
DE["ZENIAL Community detected"]="ZENIAL Community erkannt"
DE["Cross-faction chat: supported (protocol %d)"]="Cross-Faction-Chat: unterstützt (Protokoll %d)"
DE["Last confirmed contact: %s ago"]="Letzter bestätigter Kontakt: vor %s"
DE["Last confirmed contact: just now"]="Letzter bestätigter Kontakt: gerade eben"
DE["Not confirmed in this session yet"]="In dieser Sitzung noch nicht bestätigt"
DE["%d min"]="%d Minuten"
DE["%d h"]="%d Stunden"
DE["%d d"]="%d Tagen"
DE["Cross-faction"]="Cross-Faction"
DE["Show ZENIAL icons in chat"]="ZENIAL-Icons im Chat anzeigen"
DE["Show ZENIAL icon on target"]="ZENIAL-Icon am Ziel anzeigen"
DE["Enable cross-faction chat (/z, /zy)"]="Cross-Faction-Chat aktivieren (/z, /zy)"
DE["Detect ZENIAL players automatically"]="ZENIAL-Spieler automatisch erkennen"
DE["Sends an invisible addon signal to your group, guild, target and nearby players. No chat message is sent."]="Sendet ein unsichtbares Addon-Signal an Gruppe, Gilde, Ziel und Spieler in der Nähe. Es wird keine Chatnachricht gesendet."
DE["Detect ZENIAL players through Battle.net"]="ZENIAL-Spieler über Battle.net erkennen"
DE["Messages sent with /z are visible to everyone nearby as coded words. Only players with ZENIAL Community can read them."]="Mit /z gesendete Nachrichten sehen alle in der Nähe als codierte Wörter. Lesen können sie nur Spieler mit ZENIAL Community."
DE["No icon does not mean a player has no ZENIAL addon. It only means no signal has been received yet."]="Kein Icon heißt nicht, dass ein Spieler kein ZENIAL-Addon hat. Es wurde nur noch kein Signal empfangen."
DE["Open / close Zenial Community"]="Zenial Community öffnen / schließen"
DE["Show page: Start"]="Seite anzeigen: Start"
DE["Show page: Members"]="Seite anzeigen: Mitspieler"
DE["Show page: Activities"]="Seite anzeigen: Aktivitäten"
DE["Show page: Quests"]="Seite anzeigen: Quests"
DE["Show page: Crafting"]="Seite anzeigen: Handwerk"
DE["Show page: Trade"]="Seite anzeigen: Handel"
DE["Show page: My Characters"]="Seite anzeigen: Meine Charaktere"
DE["Open the PvP help request form"]="Formular „PvP-Hilfe anfordern“ öffnen"
DE["Show PvP help calls"]="PvP-Hilferufe anzeigen"
DE["Deck slot %d: open whisper"]="Deck-Slot %d: Flüstern öffnen"
DE["Deck slot %d: invite"]="Deck-Slot %d: Einladen"
DE["Deck slot %d: show profile"]="Deck-Slot %d: Profil anzeigen"
DE["Deck slot %d is not assigned."]="Deck-Slot %d ist nicht belegt."
DE["ZENIAL Deck: no free key combination is left. Assign the remaining actions under Key Bindings."]="ZENIAL Deck: Keine freie Tastenkombination mehr. Belege die übrigen Aktionen in der Tastaturbelegung."
DE["ZENIAL Deck is not available."]="ZENIAL Deck ist nicht verfügbar."
DE["ZENIAL Deck: automatic keys %s, %d of %d actions assigned, F13-F24 %s."]="ZENIAL Deck: Automatische Tasten %s, %d von %d Aktionen belegt, F13-F24 %s."
DE["ZENIAL Deck: automatic keys %s."]="ZENIAL Deck: Automatische Tasten %s."
DE["ZENIAL Deck: F13-F24 %s."]="ZENIAL Deck: F13-F24 %s."
DE["Usage: /zenial deck [on|off|fkeys on|fkeys off|slot <1-5> <name>|slot <1-5> clear]"]="Verwendung: /zenial deck [on|off|fkeys on|fkeys off|slot <1-5> <Name>|slot <1-5> clear]"
DE["Deck slot %d cleared."]="Deck-Slot %d geleert."
DE["Deck slot %d: %s"]="Deck-Slot %d: %s"
DE["Deck slot %d: no known player named %s."]="Deck-Slot %d: Kein bekannter Spieler namens %s."
-- Zenial Deck dialog
DE["Automatic keys"]="Automatische Tasten"
DE["Actions assigned"]="Aktionen belegt"
DE["%d of %d"]="%d von %d"
DE["Assign keys automatically"]="Tasten automatisch vergeben"
DE["The Companion export is off, so no keys are assigned."]="Der Companion-Export ist aus, deshalb werden keine Tasten vergeben."
DE["Waiting for the end of combat."]="Wartet auf das Kampfende."
DE["No free key combination is left. Assign the remaining actions under Key Bindings."]="Keine freie Tastenkombination mehr. Belege die übrigen Aktionen in der Tastaturbelegung."
DE["Favorite slots"]="Favoriten-Slots"
DE["not assigned"]="nicht belegt"
DE["no key"]="keine Taste"
DE["Choose favorite"]="Favorit wählen"
DE["Use target"]="Ziel übernehmen"
DE["Clear"]="Leeren"
DE["Mark fellow players as favorites (star) to pick them here."]="Markiere Mitspieler als Favorit (Stern), um sie hier auszuwählen."
DE["Target a player first."]="Wähle zuerst einen Spieler als Ziel."
DE["The target is not a known contact."]="Das Ziel ist kein bekannter Kontakt."
DE["You can also set the keys yourself in the key bindings under \"Zenial Community\"."]="Du kannst die Tasten auch selbst in der Tastaturbelegung unter „Zenial Community“ festlegen."
-- ZENIAL Rivalry: history texts and the kill-feed banner.
DE["Killed %s"]="%s getötet"
DE["Killed by %s"]="Von %s getötet"
DE["Assist against %s"]="Assist gegen %s"
DE["%s took part in your death"]="%s war an deinem Tod beteiligt"
DE["Duel won against %s"]="Duell gegen %s gewonnen"
DE["Duel lost against %s"]="Duell gegen %s verloren"
DE["Open world"]="Offene Welt"
DE["Battleground"]="Schlachtfeld"
DE["Instance"]="Instanz"
DE["Duel"]="Duell"
DE["KILLED BY"]="GETÖTET VON"
DE["DUEL WON"]="DUELL GEWONNEN"
DE["DUEL LOST"]="DUELL VERLOREN"
DE["Deaths %d"]="Tode %d"
DE["Duels %d : %d"]="Duelle %d : %d"
DE["RIVAL"]="RIVALE"
DE["NEMESIS"]="ERZFEIND"
DE["REVENGE"]="REVANCHE"
DE["FIRST MEETING"]="ERSTE BEGEGNUNG"
DE["Drag to move the banner"]="Ziehen, um das Banner zu verschieben"
-- ZENIAL Rivalry: main-window page and settings view.
DE["Call for help when you are attacked, or help others"]="Ruf Hilfe, wenn du angegriffen wirst, oder hilf anderen"
DE["Kills, deaths and duels against other players"]="Kills, Tode und Duelle gegen andere Spieler"
DE["Rivalry"]="Rivalen"
DE["Opponents"]="Gegner"
DE["This character"]="Dieser Charakter"
DE["Deaths"]="Tode"
DE["Duels"]="Duelle"
DE["Nemesis: %s has killed you %d times"]="Erzfeind: %s hat dich %d-mal getötet"
DE["Most frequent rivals"]="Häufigste Rivalen"
DE["Defeated most often"]="Am häufigsten besiegt"
DE["Killed you most often"]="Hat dich am häufigsten getötet"
DE["Fought most recently"]="Zuletzt bekämpft"
DE["No entries yet"]="Noch keine Einträge"
DE["No PvP fights recorded yet"]="Noch keine PvP-Kämpfe aufgezeichnet"
DE["Kills, deaths, assists and duels are recorded automatically."]="Kills, Tode, Assists und Duelle werden automatisch aufgezeichnet."
DE["This history was saved by a newer addon version."]="Dieser Verlauf wurde von einer neueren Addon-Version gespeichert."
DE["Rivals"]="Rivalen"
DE["Defeated"]="Besiegt"
DE["Killed me"]="Haben mich getötet"
DE["Last fight"]="Letzter Kampf"
DE["Most fights"]="Meiste Kämpfe"
DE["K %d · D %d · A %d"]="K %d · T %d · A %d"
DE["Details unknown"]="Details unbekannt"
DE["Rival"]="Rivale"
DE["Nemesis"]="Erzfeind"
DE["Record"]="Bilanz"
DE["Kills %d · Deaths %d · Assists %d"]="Kills %d · Tode %d · Assists %d"
DE["%d won · %d lost"]="%d gewonnen · %d verloren"
DE["Fights in total"]="Kämpfe insgesamt"
DE["First fight"]="Erster Kampf"
DE["Places"]="Orte"
DE["Streak"]="Serie"
DE["%d kills in a row"]="%d Kills in Folge"
DE["%d deaths in a row"]="%d Tode in Folge"
DE["Select an opponent."]="Wähle einen Gegner."
DE["In sight"]="In Sicht"
DE["Out of sight · %d s"]="Außer Sicht · %d s"
DE["Last seen · %d s"]="Zuletzt gesehen · %d s"
DE["Reported by the group · %d s"]="Von der Gruppe gemeldet · %d s"
DE["Remove opponent"]="Gegner entfernen"
DE["Confirm removal"]="Entfernen bestätigen"
DE["Opponent removed."]="Gegner entfernt."
DE["Banner settings"]="Banner-Einstellungen"
DE["Show banner"]="Banner anzeigen"
DE["Style"]="Stil"
DE["Compact"]="Kompakt"
DE["Size"]="Größe"
DE["Display time"]="Anzeigedauer"
DE["Preview"]="Vorschau"
DE["Move banner"]="Banner verschieben"
DE["Lock position"]="Position sperren"
DE["Delete this character's history"]="Verlauf dieses Charakters löschen"
DE["History deleted."]="Verlauf gelöscht."
DE["PvP history"]="PvP-Verlauf"
DE["Show record in player tooltips"]="Bilanz im Spieler-Tooltip anzeigen"
-- My characters 2.0: Professions and Inventory tabs
DE["By character"]="Nach Charakter"
DE["By profession"]="Nach Beruf"
DE["Character"]="Charakter"
DE["Backpack"]="Rucksack"
DE["Bag %d"]="Tasche %d"
DE["Bank bag %d"]="Banktasche %d"
-- My characters 2.0: container names
DE["Reagent bag"]="Reagenzientasche"
DE["Bank tab %d"]="Bankfach %d"
DE["Bags not recorded yet"]="Taschen noch nicht erfasst"
DE["Bank not recorded yet – open your bank once"]="Bank noch nicht erfasst – Bank einmal öffnen"
DE["Older record without bag slots"]="Ältere Erfassung ohne Taschenplätze"
-- My characters 2.0: Recipes tab
DE["Search recipe"]="Rezept suchen"
DE["Required"]="Benötigt"
DE["No recipes recorded yet."]="Noch keine Rezepte erfasst."
DE["No matching recipes."]="Keine passenden Rezepte."
DE["Recipe scan incomplete – missing recipes are not \"not learned\"."]="Rezeptscan unvollständig – fehlende Rezepte sind nicht „nicht gelernt“."
DE["Back to list"]="Zurück zur Liste"
DE["Known by: %s"]="Bekannt bei: %s"
DE["Crafter"]="Hersteller"
DE["Crafts"]="Anzahl"
DE["Bank/Alts"]="Bank/Twinks"
DE["Missing"]="Fehlt"
DE["Craftable now"]="Sofort herstellbar"
DE["Possible account-wide"]="Accountweit möglich"
DE["at least %d"]="mind. %d"
DE["Not fully calculable"]="Nicht vollständig berechenbar"
DE["The materials of this recipe are unknown."]="Die Materialien dieses Rezepts sind unbekannt."
DE["~ Not every place is recorded."]="~ Nicht jeder Ort ist erfasst."
DE["* Saved more than 7 days ago."]="* Vor über 7 Tagen erfasst."
DE["Gather materials"]="Materialien zusammenstellen"
DE["Hide plan"]="Plan ausblenden"
DE["Collect"]="Einsammeln"
DE["To get"]="Zu beschaffen"
DE["Nothing to collect."]="Nichts einzusammeln."
DE["from %s"]="von %s"
DE["Received"]="Empfangen"
DE["Sent"]="Gesendet"
DE["Other contacts"]="Weitere Kontakte"
DE["Through a community member"]="Über ein Community-Mitglied"
DE["For other players"]="Für andere Spieler"
DE["Presence"]="Präsenz"
DE["Presence, profile"]="Präsenz, Profil"
DE["Presence, profile, offers, map"]="Präsenz, Profil, Angebote, Karte"
DE["Not joined"]="Nicht beigetreten"
DE["No connection yet"]="Noch keine Verbindung"
DE["Appearing offline"]="Als offline angezeigt"
DE["Disconnected"]="Getrennt"
DE["Nobody reachable"]="Niemand erreichbar"
DE["No guild"]="Keine Gilde"
DE["No group"]="Keine Gruppe"
DE["Detection off"]="Erkennung aus"
DE["Not needed"]="Nicht nötig"
DE["Loading from %s"]="Lädt von %s"
DE["Through %s"]="Über %s"
DE["No member reachable"]="Kein Mitglied erreichbar"
DE["Answering"]="Antwortet"
DE["Nobody asking"]="Niemand fragt"
DE["Updated %s"]="Stand: %s"
DE["Local network"]="Lokales Netzwerk"
DE["direct"]="direkt"
DE["indirect"]="indirekt"
DE["gateway"]="Gateway"
DE["Filter (%d)"]="Filter (%d)"
DE["Free place for"]="Platz frei für"
DE["Already has"]="Hat schon"
DE["Play style"]="Spielstil"
DE["Classes"]="Klassen"
DE["None"]="Keine"
DE["Saved filters"]="Gespeicherte Filter"
DE["Save filter"]="Filter speichern"
DE["Delete filter"]="Filter löschen"
DE["Nothing matches your filters."]="Nichts passt zu deinen Filtern."
DE["You can save up to %d filters. Delete one first."]="Du kannst bis zu %d Filter speichern. Lösche zuerst einen."
DE["Rated"]="Bewertet"
DE["Poorly rated"]="Schlecht bewertet"
DE["Rating"]="Bewertung"
DE["Private comment"]="Kommentar (privat)"
DE["Remove rating"]="Bewertung entfernen"
DE["Invalid rating."]="Ungültige Bewertung."
DE["Rate your group"]="Gruppe bewerten"
DE["%s left the group"]="%s hat die Gruppe verlassen"
DE["Players left the group"]="Spieler haben die Gruppe verlassen"
DE["Ask for a rating after dungeons"]="Nach Dungeons um Bewertung bitten"
DE["Remove"]="Entfernen"
DE["Clear whispers"]="Flüsteranfragen leeren"
DE["Last message"]="Letzte Nachricht"
DE["Earlier messages"]="Frühere Nachrichten"
DE["%d messages"]="%d Nachrichten"
DE["Poorly rated player in the group"]="Schlecht bewerteter Spieler in der Gruppe"
DE["Rate player"]="Spieler bewerten"
DE["Rate player (%d/5)"]="Spieler bewerten (%d/5)"
DE["More filters"]="Weitere Filter"
DE["More filters (%d)"]="Weitere Filter (%d)"
DE["Not searched: you were in combat. Click Refresh."]="Nicht gesucht: Du warst im Kampf. Klicke auf Aktualisieren."
DE["Not searched: the game did not allow it right then. Click Refresh."]="Nicht gesucht: Das Spiel hat es gerade nicht erlaubt. Klicke auf Aktualisieren."
DE["Not searched: a search had just run. Click Refresh."]="Nicht gesucht: Gerade lief schon eine Suche. Klicke auf Aktualisieren."
DE["Not searched: another search was running. Click Refresh."]="Nicht gesucht: Eine andere Suche lief noch. Klicke auf Aktualisieren."
