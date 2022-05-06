// Workhorse class for resetting the bodies of a collection of letters.
public class LetterReset {
    public LetterReset() {
    }

    public class letterResetException extends Exception {
    }
    private String defaultLanguage = Utilities.defaultLanguage();

    // Declare caches for previously expanded macros and pieces of a given letter.
    private Map<String, Object> mCache;
    private Map<String, String> pCache;
    // Declare handy maps for IDs, names, and texts of macros and pieces.
    private Map<Id, Template_macro__c> mMap, mMapGen;
    private Map<Id, Template_piece__c> pMap, pMapGen;
    private Map<Id, Map<String, Id>> mNameMap; // template ID -> macro name -> macro ID
    private Map<String, Id> mNameMapGen; // macro name -> macro ID
    private Map<Id, Map<String, Map<String, Id>>> pNameMap; // template ID -> piece name -> language -> piece ID
    private Map<String, Map<String, Id>> pNameMapGen; // piece name -> language -> piece ID
    private Map<Id, Map<Id, Map<String, Map<String, Id>>>> pNameMapRepReqs; // template ID -> reporting reqs ID -> piece name -> language -> piece ID
    private Map<Id, Map<String, Map<String, Id>>> pNameMapRepReqsGen; // reporting reqs ID -> piece name -> language -> piece ID
    private Map<String, Set<Id>> fieldsMacrosMap, fieldsPiecesMap; // field name -> macro IDs; field name -> piece IDs
    // Gather field names from all template macros/pieces, use SOQL to grab field values,
    // fetch template assigned to each letter.  Then use recursive helper methods to
    // instantiate template and its pieces,
    // expand/interpret macros, and finally, look up field values.
    // Return list of letter Ids that couldn't be reset because of non-blank Date Sent.
    public List<Id> resetLettersHandler(Set<Id> letIds) {
        // Gather active template macros belonging to the templates used in the given letters, as well as any generic ones.
        mMap = new Map<Id, Template_macro__c>(
            [
                SELECT Name, Macro_text__c, Template__c
                FROM Template_macro__c
                WHERE
                    Active__c = true
                    AND Template__c IN (
                        SELECT Template__c
                        FROM Letter__c
                        WHERE Id IN :letIds
                    )
            ]
        );
        mMapGen = new Map<Id, Template_macro__c>(
            [
                SELECT Name, Macro_text__c, Template__c
                FROM Template_macro__c
                WHERE Active__c = true AND Template__c = null
            ]
        );
        // Gather active template pieces belonging to the templates used in the given letters, as well as any generic ones.
        pMap = new Map<Id, Template_piece__c>(
            [
                SELECT
                    Name,
                    Piece_text__c,
                    Template__c,
                    Custom_Reqs__c,
                    Language__c
                FROM Template_piece__c
                WHERE
                    Active__c = true
                    AND Template__c IN (
                        SELECT Template__c
                        FROM Letter__c
                        WHERE Id IN :letIds
                    )
            ]
        );
        pMapGen = new Map<Id, Template_piece__c>(
            [
                SELECT
                    Name,
                    Piece_text__c,
                    Template__c,
                    Custom_Reqs__c,
                    Language__c
                FROM Template_piece__c
                WHERE Active__c = true AND Template__c = null
            ]
        );
        // Build look-up maps.
        mNameMap = new Map<Id, Map<String, Id>>(); // template ID -> macro name -> macro ID
        mNameMapGen = new Map<String, Id>(); // macro name -> macro ID
        pNameMap = new Map<Id, Map<String, Map<String, Id>>>(); // template ID -> piece name -> language -> piece ID
        pNameMapGen = new Map<String, Map<String, Id>>(); // piece name -> language -> piece ID
        pNameMapRepReqs = new Map<Id, Map<Id, Map<String, Map<String, Id>>>>(); // template ID -> reporting reqs ID -> piece name -> language -> piece ID
        pNameMapRepReqsGen = new Map<Id, Map<String, Map<String, Id>>>(); // reporting reqs ID -> piece name -> language -> piece ID
        fieldsMacrosMap = new Map<String, Set<Id>>(); // field name -> macro IDs
        fieldsPiecesMap = new Map<String, Set<Id>>(); // field name -> piece IDs
        // Populate macros map and concatenate text from all active template macros.
        for (Template_macro__c m : mMap.values()) {
            if (!mNameMap.containsKey(m.Template__c))
                mNameMap.put(m.Template__c, new Map<String, Id>());
            mNameMap.get(m.Template__c).put(m.Name, m.Id);
            saveMacroFields(m.Id, m.Macro_text__c);
        }
        for (Template_macro__c m : mMapGen.values()) {
            mNameMapGen.put(m.Name, m.Id);
            saveMacroFields(m.Id, m.Macro_text__c);
        }
        // Populate pieces map and gather more merge fields from active template pieces.
        for (Template_piece__c p : pMap.values()) {
            if (p.Custom_Reqs__c != null) {
                // If piece is defined for a reporting reqs, then populate reporting reqs-based piece map.
                if (!pNameMapRepReqs.containsKey(p.Template__c))
                    pNameMapRepReqs.put(
                        p.Template__c,
                        new Map<Id, Map<String, Map<String, Id>>>()
                    );
                if (
                    !pNameMapRepReqs.get(p.Template__c)
                        .containsKey(p.Custom_Reqs__c)
                )
                    pNameMapRepReqs.get(p.Template__c)
                        .put(
                            p.Custom_Reqs__c,
                            new Map<String, Map<String, Id>>()
                        );
                if (
                    !pNameMapRepReqs.get(p.Template__c)
                        .get(p.Custom_Reqs__c)
                        .containsKey(p.Name)
                )
                    pNameMapRepReqs.get(p.Template__c)
                        .get(p.Custom_Reqs__c)
                        .put(p.Name, new Map<String, Id>());
                pNameMapRepReqs.get(p.Template__c)
                    .get(p.Custom_Reqs__c)
                    .get(p.Name)
                    .put(p.Language__c, p.Id);
            } else {
                // If piece is a default, then populate non-reporting reqs based piece map.
                if (!pNameMap.containsKey(p.Template__c))
                    pNameMap.put(
                        p.Template__c,
                        new Map<String, Map<String, Id>>()
                    );
                if (!pNameMap.get(p.Template__c).containsKey(p.Name))
                    pNameMap.get(p.Template__c)
                        .put(p.Name, new Map<String, Id>());
                pNameMap.get(p.Template__c)
                    .get(p.Name)
                    .put(p.Language__c, p.Id);
            }
            savePieceFields(p.Id, p.Piece_text__c);
            system.debug(
                'LetterReset in piece loop, p.Name: ' +
                p.Name +
                '; p.Piece_text__c: ' +
                p.Piece_text__c
            );
        }
        // Populate generic pieces map and gather more merge fields from active generic template pieces.
        for (Template_piece__c p : pMapGen.values()) {
            if (p.Custom_Reqs__c != null) {
                // If generic piece is defined for a reporting reqs, then populate reporting reqs-based generic piece map.
                if (!pNameMapRepReqsGen.containsKey(p.Custom_Reqs__c))
                    pNameMapRepReqsGen.put(
                        p.Custom_Reqs__c,
                        new Map<String, Map<String, Id>>()
                    );
                if (
                    !pNameMapRepReqsGen.get(p.Custom_Reqs__c)
                        .containsKey(p.Name)
                )
                    pNameMapRepReqsGen.get(p.Custom_Reqs__c)
                        .put(p.Name, new Map<String, Id>());
                pNameMapRepReqsGen.get(p.Custom_Reqs__c)
                    .get(p.Name)
                    .put(p.Language__c, p.Id);
            } else {
                // If generic piece is a default, then populate non-reporting reqs based generic piece map.
                if (!pNameMapGen.containsKey(p.Name))
                    pNameMapGen.put(p.Name, new Map<String, Id>());
                pNameMapGen.get(p.Name).put(p.Language__c, p.Id);
            }
            savePieceFields(p.Id, p.Piece_text__c);
            system.debug(
                'LetterReset in generic piece loop, p.Name: ' +
                p.Name +
                '; p.Piece_text__c: ' +
                p.Piece_text__c
            );
        }
        // Get values of referenced fields for given letters, adding __r notation to related field names.
        Set<String> fNamesSet = new Set<String>{
            'Template__c',
            'Page_1__c',
            'Page_2__c',
            'Page_3__c',
            'Page_4__c',
            'Page_5__c',
            'Language__c',
            'Custom_Reqs__c',
            'Date_sent__c'
        };
        fNamesSet.addAll(fieldsMacrosMap.keySet());
        fNamesSet.addAll(fieldsPiecesMap.keySet());
        List<String> fNames = Utilities.massageFieldNames(
            new List<String>(fNamesSet)
        );
        system.debug(
            'LetterReset: original fNames = ' +
            JSON.serialize(fNamesSet) +
            '; massaged fNames = ' +
            JSON.serialize(fNames)
        );
        String q =
            'SELECT ' +
            String.join(fNames, ', ') +
            ' FROM Letter__c WHERE Id IN : letIds';
        system.debug('LetterReset: before loop: q = ' + q);
        Map<Id, Letter__c> letMap;
        try {
            letMap = new Map<Id, Letter__c>(
                (List<Letter__c>) database.query(q)
            );
        } catch (Exception e) {
            throw new letterResetException(
                'LetterReset error gathering field values with query = ' +
                q +
                '; ' +
                e.getMessage() +
                '\n' +
                getLocations(q + ' ' + e.getMessage())
            );
        }

        // Loop through the letters, resetting the text of each.
        system.debug(
            'LetterReset: before loop: mMap = ' + JSON.serialize(mMap)
        );
        system.debug(
            'LetterReset: before loop: mMapGen = ' + JSON.serialize(mMapGen)
        );
        system.debug(
            'LetterReset: before loop: pMap = ' + JSON.serialize(pMap)
        );
        system.debug(
            'LetterReset: before loop: pMapGen = ' + JSON.serialize(pMapGen)
        );
        system.debug(
            'LetterReset: before loop: mNameMap = ' + JSON.serialize(mNameMap)
        );
        system.debug(
            'LetterReset: before loop: mNameMapGen = ' +
            JSON.serialize(mNameMapGen)
        );
        system.debug(
            'LetterReset: before loop: pNameMap = ' + JSON.serialize(pNameMap)
        );
        system.debug(
            'LetterReset: before loop: pNameMapGen = ' +
            JSON.serialize(pNameMapGen)
        );
        system.debug(
            'LetterReset: before loop: pNameMapRepReqs = ' +
            JSON.serialize(pNameMapRepReqs)
        );
        system.debug(
            'LetterReset: before loop: pNameMapRepReqsGen = ' +
            JSON.serialize(pNameMapRepReqsGen)
        );
        // Save and return list of letter Ids that couldn't be reset due to non-blank date sent.
        List<Id> sentLetIds = new List<Id>();
        for (Letter__c let : letMap.values()) {
            if (let.Date_sent__c != null) {
                // Letter has already been emailed or printed - disallow reset.
                sentLetIds.add(let.Id);
                continue;
            }
            Id tId = let.Template__c;
            // Initialize macro/piece caches.
            mCache = new Map<String, Object>();
            pCache = new Map<String, String>();
            // Expand the PAGE template pieces from this letter's template
            if (
                !pNameMapRepReqs.containsKey(tId) && !pNameMap.containsKey(tId)
            ) {
                let.Page_1__c =
                    '**NO TEMPLATE PIECES DEFINED FOR TEMPLATE ' +
                    tId +
                    '**';
            } else {
                // PAGE 1 piece is required, other pages are optional.
                String page1Name = 'PAGE 1';
                String page1 = getPieceText(let, page1Name);
                String page2 = getPieceText(let, 'PAGE 2');
                String page3 = getPieceText(let, 'PAGE 3');
                String page4 = getPieceText(let, 'PAGE 4');
                String page5 = getPieceText(let, 'PAGE 5');
                String eSubj = getPieceText(let, 'Email subject');
                String eFoot = getPieceText(let, 'Email footer');
                String eNotificationSubj = getPieceText(
                    let,
                    'NotificationEmailSubject'
                );
                String eNotificationBody = getPieceText(
                    let,
                    'NotificationEmailBody'
                );
                if (page1 != '**NOT FOUND**') {
                    let.Page_1__c = expandText(page1, let)
                        .replaceAll('\n', '<BR>');
                } else {
                    let.Page_1__c =
                        '**NO PAGE 1 TEMPLATE PIECE FOR TEMPLATE ' +
                        tId +
                        '**';
                }
                let.Page_2__c = (page2 != '**NOT FOUND**')
                    ? expandText(page2, let).replaceAll('\n', '<BR>')
                    : '';
                let.Page_3__c = (page3 != '**NOT FOUND**')
                    ? expandText(page3, let).replaceAll('\n', '<BR>')
                    : '';
                let.Page_4__c = (page4 != '**NOT FOUND**')
                    ? expandText(page4, let).replaceAll('\n', '<BR>')
                    : '';
                let.Page_5__c = (page5 != '**NOT FOUND**')
                    ? expandText(page5, let).replaceAll('\n', '<BR>')
                    : '';
                let.Email_subject__c = (eSubj != '**NOT FOUND**')
                    ? expandText(eSubj, let).replaceAll('\n', '<BR>')
                    : '';
                let.Email_footer__c = (eFoot != '**NOT FOUND**')
                    ? expandText(eFoot, let).replaceAll('\n', '<BR>')
                    : '';
                let.Notification_email_subject__c = (eNotificationSubj !=
                    '**NOT FOUND**')
                    ? expandText(eNotificationSubj, let)
                            .replaceAll('\n', '<BR>')
                    : '';
                let.Notification_email_body__c = (eNotificationBody !=
                    '**NOT FOUND**')
                    ? expandText(eNotificationBody, let)
                            .replaceAll('\n', '<BR>')
                    : '';
            }
        }
        update letMap.values();
        return sentLetIds;
    }

    // Find field names in given macro text and stash in lookup map structure.
    private void saveMacroFields(Id macroId, String mText) {
        // Extract referenced field names from macro text.
        ExpressionLexer lexer = new ExpressionLexer(
            mText,
            ExpressionInterpreter.symbols
        );
        for (String f : lexer.fieldNames()) {
            if (f == null || f.trim().length() == 0 || f == 'null')
                throw new letterResetException(
                    'saveMacroFields: Found null/blank fieldname in macro ' +
                    macroId +
                    ': ' +
                    mText.left(255)
                );
            if (!fieldsMacrosMap.containsKey(f))
                fieldsMacrosMap.put(f, new Set<Id>());
            fieldsMacrosMap.get(f).add(macroId);
        }
    }

    // Find field names in given piece text and stash in lookup map structure.
    private void savePieceFields(Id pieceId, String pText) {
        // Extract referenced field names from piece text.
        for (String f : Utilities.getMergeFields(pText)) {
            if (f == null || f.trim().length() == 0 || f == 'null')
                throw new letterResetException(
                    'savePieceFields: Found null/blank fieldname in piece ' +
                    pieceId +
                    ': ' +
                    pText.left(255)
                );
            if (!fieldsPiecesMap.containsKey(f))
                fieldsPiecesMap.put(f, new Set<Id>());
            fieldsPiecesMap.get(f).add(pieceId);
        }
    }

    // Describe macro/piece locations of the unknown field (if any) in query.
    private String getLocations(String message) {
        system.debug('Top of getLocations: message = ' + message);
        String result;
        String fName;
        // Grab name of unknown field.
        String eString1 = 'UNKNOWN FIELD:';
        String eString2 = 'No such column';
        Integer eIndex1 = message.indexOf(eString1);
        Integer eIndex2 = message.indexOf(eString2);
        system.debug('eIndex1 = ' + eIndex1 + '; eIndex2 = ' + eIndex2);
        if (eIndex1 >= 0) {
            Integer start = eIndex1 + eString1.length();
            Integer commaIndex = message.indexOf(', ', eIndex1);
            Integer FROMIndex = message.indexOf(' FROM ', eIndex1);
            fName = (commaIndex > eIndex1 &&
                commaIndex < FROMIndex)
                ? message.substring(start, commaIndex)
                : message.substring(start, FROMIndex);
            return getNameLocations(fName);
        } else if (eIndex2 >= 0) {
            // Next two quoted strings are field name and object name
            List<String> quotedWords = message.substring(eIndex2)
                .split('\\\'', 0);
            system.debug(
                'no such column: quotedWords = ' + JSON.serialize(quotedWords)
            );
            // Look for the culprit field name with and without the object reference part.
            String objRef = (quotedWords[3] == 'Account' ||
                quotedWords[3] == 'Contact')
                ? quotedWords[3] + '__c'
                : quotedWords[3];
            result = getNameLocations(objRef + '.' + quotedWords[1]);
            if (result != null)
                return result;
            result = getNameLocations(quotedWords[1]);
            if (result != null)
                return result;
        }
        return '';
    }

    private String getNameLocations(String fName) {
        String result;
        // Build description of field locations in macros and/or pieces.
        if (fieldsMacrosMap.containsKey(fName)) {
            result = result + '\nOccurences of ' + fName + ' in macros:';
            for (Id i : fieldsMacrosMap.get(fName)) {
                if (mMap.containsKey(i))
                    result = result + '\n' + mMap.get(i).name;
                if (mMapGen.containsKey(i))
                    result = result + '\n' + mMapGen.get(i).name;
            }
        }
        if (fieldsPiecesMap.containsKey(fName)) {
            result = result + '\nOccurences of ' + fName + ' in pieces:';
            for (Id i : fieldsPiecesMap.get(fName)) {
                if (pMap.containsKey(i))
                    result =
                        result +
                        '\n' +
                        pMap.get(i).name +
                        '(' +
                        pMap.get(i).language__c +
                        ')';
                if (pMapGen.containsKey(i))
                    result =
                        result +
                        '\n' +
                        pMapGen.get(i).name +
                        '(' +
                        pMapGen.get(i).language__c +
                        ')';
            }
        }
        return result;
    }

    // Expand the letter text based on a template, its pieces, and any embedded macros.
    private String expandText(String text, Letter__c let) {
        Integer pos = 0;
        while (pos < text.length()) {
            system.debug(
                'LetterReset expandText while loop: pos = ' +
                pos +
                '; text = ' +
                text
            );
            Integer startMacro = text.indexOf('[[', pos);
            Integer endMacro = text.indexOf(']]', startMacro);
            Integer startPiece = text.indexOf('{{', pos);
            Integer endPiece = text.indexOf('}}', startPiece);
            if (startMacro >= 0 && endMacro < startMacro)
                return '**COULD NOT EXPAND MACRO: UNBALANCED DOUBLE SQUARE BRACKETS [[...]]**';
            if (startPiece >= 0 && endPiece < startPiece)
                return '**COULD NOT EXPAND PIECE: UNBALANCED DOUBLE CURLY BRACKETS {{...}}**';
            if (
                pos <= startMacro &&
                (startPiece < pos ||
                startMacro < startPiece)
            ) {
                // There's a macro and it's before any piece.
                Object expandedMacro = expandMacro(
                    text.substring(startMacro + 2, endMacro),
                    let
                );
                text = text.replace(
                    text.substring(startMacro, endMacro + 2),
                    (expandedMacro == null) ? '' : String.valueof(expandedMacro)
                );
                pos = startMacro;
            } else if (pos <= startPiece) {
                // Else the piece (if any) occurs before any macro.
                text = text.replace(
                    text.substring(startPiece, endPiece + 2),
                    expandPiece(text.substring(startPiece + 2, endPiece), let)
                );
                pos = startPiece;
            } else {
                // No pieces/macros to expand, so grab rest of text into result and get out.
                pos = text.length();
            }
        }
        return Utilities.evalMergeFields(text, let);
    }

    // Expand a macro's text.
    private Object expandMacro(String mName, Letter__c let) {
        system.debug('LetterReset expandMacro: mName = ' + mName);
        // Use cache to check if we're (recursively) in the middle of this macro's expansion, or if we've already expanded it.
        if (mCache.containsKey(mName)) {
            Object mCached = mCache.get(mName);
            if (mCached == '@@EXPANDING@@')
                return '**UNABLE TO EXPAND ' + mName + ': RECURSIVE CALL';
            return mCached;
        }
        // Look up this macro. Look for a generic if there's none associated with this template.
        Id mId;
        if (mNameMap.get(let.Template__c) != null)
            mId = mNameMap.get(let.Template__c).get(mName);
        if (mId == null)
            mId = mNameMapGen.get(mName);
        if (mId == null)
            return '**UNABLE TO EXPAND ' + mName + ': UNKNOWN MACRO';
        // Expand macro text using expression parser after flagging in the cache that it's in the process of being expanded.
        mCache.put(mName, '@@EXPANDING@@');
        // Get macro text from the template-specific macro stash, or, failing that, from the generic macro stash.
        String mText = (mMap.get(mId) != null)
            ? mMap.get(mId).Macro_text__c
            : mMapGen.get(mId).Macro_text__c;
        // Recursively expand embedded macros, and then this top-level macro.
        // NOTE: We don't expand sub-macros with expandText, because that would expand pieces that are enclosed in double-quotes.
        mText = expandEmbeddedMacros(mText, let);
        Object mExpanded;
        try {
            ExpressionInterpreter parser = new ExpressionInterpreter(let);
            mExpanded = parser.interpret(mText);
        } catch (Exception e) {
            throw new letterResetException(
                'LetterReset error expanding macro ' +
                mName +
                '; ' +
                e.getMessage()
            );
        }
        system.debug('expandMacro: mExpanded = ' + JSON.serialize(mExpanded));
        system.debug('expandMacro: mCache = ' + JSON.serialize(mCache));
        mCache.put(mName, mExpanded);
        return mExpanded;
    }

    // Expand embedded macro calls inside a newly expanded macro.
    private String expandEmbeddedMacros(String text, Letter__c let) {
        Integer pos = 0;
        while (pos < text.length()) {
            system.debug(
                'LetterReset expandEmbeddedMacros while loop: pos = ' +
                pos +
                '; text = ' +
                text
            );
            Integer startMacro = text.indexOf('[[', pos);
            Integer endMacro = text.indexOf(']]', startMacro);
            if (startMacro >= 0 && endMacro < startMacro)
                return '**COULD NOT EXPAND MACRO: UNBALANCED DOUBLE SQUARE BRACKETS [[...]]**';
            if (pos <= startMacro) {
                // There's a macro.
                text = text.replace(
                    text.substring(startMacro, endMacro + 2),
                    quote(
                        expandMacro(
                            text.substring(startMacro + 2, endMacro),
                            let
                        )
                    )
                );
                pos = startMacro;
            } else {
                // No macros to expand, so grab rest of text into result and get out.
                pos = text.length();
            }
        }
        return text;
    }

    // "Quote" the result of an embedded macro so it can be re-processed by the enclosing macro.
    private String quote(Object o) {
        if (o == null) {
            return 'null';
        } else if (o instanceof String) {
            return '"' + (String) o + '"';
        } else if (o instanceof Date) {
            return 'DATE(' +
                ((Date) o).year() +
                ',' +
                ((Date) o).month() +
                ',' +
                ((Date) o).day() +
                ')';
        } else {
            return String.valueof(o);
        }
    }

    // Expand a piece's text.
    private String expandPiece(String pName, Letter__c let) {
        system.debug('LetterReset expandPiece: pName = ' + pName);
        // Use cache to check if we're (recursively) in the middle of this piece's expansion, or if we've already expanded it.
        String pExpanded = pCache.get(pName);
        if (pExpanded == '@@EXPANDING@@')
            return '**UNABLE TO EXPAND ' + pName + ': RECURSIVE CALL';
        if (String.isNotBlank(pExpanded))
            return pExpanded;
        // Look up text for this piece.
        String pText = getPieceText(let, pName);
        if (pText == '**NOT FOUND**')
            pText = '**UNABLE TO EXPAND ' + pName + ': UNKNOWN PIECE';
        if (pText == null)
            pText = ''; // Convert null to blank, since we took care of the "real" null case in line above.
        // Expand piece text after flagging in the cache that it's in the process of being expanded.
        pCache.put(pName, '@@EXPANDING@@');
        pExpanded = expandText(pText, let);
        pCache.put(pName, pExpanded);
        return pExpanded;
    }

    // Return text of given piece from given letter according to its template, reporting reqs (if any), and language.
    // If piece can't be found in given language, look for it in English.
    private String getPieceText(Letter__c let, String pName) {
        system.debug('LetterReset getPieceText: pName = ' + pName);
        Id tId = let.Template__c;
        Id iId = let.Custom_Reqs__c;
        String language = let.Language__c;
        Map<String, Id> lMap, lMapGen; // language -> piece ID
        // Get the appropriate language-to-piece map for the piece name, depending on whether
        // the piece is defined for the reporting reqs.
        if (
            iId != null &&
            pNameMapRepReqs.get(tId) != null &&
            pNameMapRepReqs.get(tId).get(iId) != null &&
            pNameMapRepReqs.get(tId).get(iId).get(pName) != null
        ) {
            lMap = pNameMapRepReqs.get(tId).get(iId).get(pName);
        } else if (
            pNameMap.get(tId) != null &&
            pNameMap.get(tId).get(pName) != null
        ) {
            lMap = pNameMap.get(tId).get(pName);
        }
        // If piece name not defined for the given template, then look for a generic one (possibly reporting reqs) for that piece name.
        if (lMap == null) {
            if (
                iId != null &&
                pNameMapRepReqsGen.get(iId) != null &&
                pNameMapRepReqsGen.get(iId).get(pName) != null
            ) {
                lMapGen = pNameMapRepReqsGen.get(iId).get(pName);
            } else {
                lMapGen = pNameMapGen.get(pName);
            }
        }
        // See if piece is defined for given language, otherwise default to English.
        if (lMap != null) {
            return (lMap.get(language) != null)
                ? pMap.get(lMap.get(language)).Piece_text__c
                : pMap.get(lMap.get(defaultLanguage)).Piece_text__c;
        } else if (lMapGen != null) {
            return (lMapGen.get(language) != null)
                ? pMapGen.get(lMapGen.get(language)).Piece_text__c
                : pMapGen.get(lMapGen.get(defaultLanguage)).Piece_text__c;
        } else {
            return '**NOT FOUND**';
        }
    }
}