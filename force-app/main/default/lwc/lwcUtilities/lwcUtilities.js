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
                variant: error.variant,
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

export {
    handleError,showUIError
};