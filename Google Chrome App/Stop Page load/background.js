chrome.webNavigation.onCommitted.addListener(details => {
    if (details.url.includes("accounts.google.com")) {
        console.log(`⏳ Таймер запущен для ${details.url}`);
        
        setTimeout(() => {
            chrome.scripting.executeScript({
                target: { tabId: details.tabId },
                func: () => {
                    window.stop();
                    console.log("❌ Загрузка accounts.google.com остановлена!");
                }
            });
        }, 5000);
    }
});