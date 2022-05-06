public class TemplateController {
    /* -----------------
    At the moment, this code is invoked from ProposalUpdate to calculate status.  Unlike LetterReset, this version of
    template parsing handles only template macros, not template pieces.  At some point, we need to integrate
    template pieces here, including the tricky dependencies on custom reqs.  

    Note that the primary purpose of the TemplateMacros class is to gather template macros and invoke the expression interpreter
    
    If we run into problems with processing overhead, we can consider caching the prefix for each template macro along with the dateTime on which
    the prefix json was last updated.  We would then recompute prefix for any macros whose date modified is more recent
    than the dateTime prefix was last updated. 

    -------------------- */

    // Class for processing a template's macros.  Used, for example, in status calculations.
    public class TemplateMacros {
        // Mapping from macro name to macro
        private Map<String, Template_macro__c> mNameMap = new Map<String, Template_macro__c>();

        private Id templateId;
        private Template__c template;

        private sObject context;
        private ExpressionInterpreter interpreter;

        // An instance of the class contains all relevant local and global macros.
        public TemplateMacros(Id templateId) {
            this.templateId = templateId;
            this.template = [
                SELECT Name
                FROM Template__c
                WHERE Id = :templateId
            ];
            // Fetch macros for this template as well as generic ones (not tied to a template).
            // Order results so that generics come last.
            Template_macro__c[] tms = [
                SELECT
                    Id,
                    Name,
                    Macro_text__c,
                    Template__c,
                    Macro_text_hashcode__c,
                    Macro_text_prefix__c
                FROM Template_macro__c
                WHERE
                    Active__c = true
                    AND (Template__c = null
                    OR Template__c = :templateId)
                ORDER BY Template__c DESC
            ];
            // Keep only one macro for each macro name, including generic if no local.
            for (Template_macro__c tm : tms) {
                if (!mNameMap.containsKey(tm.Name))
                    mNameMap.put(tm.Name, tm);
            }
        }

        // Update the prefix for the template's macros if the macro text no longer matches stored hashcode (because text was modified).
        public void updatePrefixes() {
            Template_macro__c[] toUpdate = new List<Template_macro__c>();
            for (Template_macro__c tm : mNameMap.values()) {
                Integer hash = System.hashCode(tm.Macro_text__c);
                if (hash != tm.Macro_text_hashcode__c) {
                    system.debug(
                        'TemplateController.toUpdate: recomputing prefix for macro ' +
                        tm.Name
                    );
                    ExpressionLexer lexer = new ExpressionLexer(
                        tm.Macro_text__c,
                        ExpressionInterpreter.symbols
                    );
                    tm.Macro_text_prefix__c = lexer.initialize(null);
                    tm.Macro_text_hashcode__c = hash;
                    toUpdate.add(tm);
                }
            }
            if (toUpdate.size() > 0)
                update toUpdate;
        }

        // Initialize the interpreter instance for this template macros object with given context.
        public void initialize(sObject context) {
            // Update the macros' cached prefixes if necessary
            updatePrefixes();
            // Reset context.
            this.context = context;
            // Use expanded macro text to build a new interpreter with initialized lexer (i.e. pre-computed prefix).
            this.interpreter = new ExpressionInterpreter(context, mNameMap);
        }

        // Evaluate a macro in the given context.
        public Object evaluate(String mName) {
            system.debug('TemplateController evaluate: mName = ' + mName);
            if (this.context == null) {
                return '**MISSING CONTEXT: Set context via initialize before calling evaluate';
            }
            // Use interpreter to evaluate macro.
            return interpreter.evaluateMacro(mName);
        }
    }
}