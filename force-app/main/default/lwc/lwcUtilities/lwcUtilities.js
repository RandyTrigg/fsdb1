import { ShowToastEvent } from 'lightning/platformShowToastEvent'

// error handler
function handleError(error) {
    console.log('error');
    console.dir(error);
    try {
        let errorObj = JSON.parse(error.body.message);
        console.log('errorObj', errorObj);
        dispatchEvent(
            new ShowToastEvent({
                title: errorObj.title,
                message: errorObj.userMessage,
                variant: errorObj.variant,
                mode: 'sticky'
            })
        )
    } catch (parseError) {
        dispatchEvent(
            new ShowToastEvent({
                title: 'Unknown Error',
                message: error.message,
                variant: 'error',
                mode: 'sticky'
            })
        )
    }
    

}

// error handler
function showUIError(error) {
    console.log('--showUIError error--')
    console.dir(error)
    // let errorObj = JSON.parse(error);
    // console.dir(errorObj)
    try { 
        dispatchEvent(
            new ShowToastEvent({
                title: error.title,
                message: error.userMessage,
                variant: 'error',
                mode: 'sticky'
            })
        )  
    } catch(parseError) {
        new ShowToastEvent({
            title: 'Unknown Error',
            message: error.message,
            variant: 'error',
            mode: 'sticky'
        })
    }                   
}

function buildError (title, message, variant) {
    let newErr = new Object();
    newErr.title = title;
    newErr.userMessage = message;
    newErr.variant = variant;
    return newErr;
}

function langTag (lang) {
    const lMap = new Map();
    lMap.set('English', 'en');
    lMap.set('Spanish', 'es');
    lMap.set('French', 'fr');
    lMap.set('Portuguese', 'pt');
    return lMap.get(lang);
}

export {
    handleError,showUIError, buildError, langTag
};