import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Item {
    id: testRoot

    NotificationServer {
        id: debugServer
        bodySupported: true
        keepOnReload: false
        
        onNotification: (n) => {
            n.tracked = true;
            console.log("=== 🔔 NEW NOTIFICATION ARRIVED ===");
            console.log("Summary: " + n.summary);
            console.log("Body:    " + n.body);
            
            // Brute force trace the internal reflection signatures
            try { console.log("Method 1 (.count):       " + debugServer.trackedNotifications.count); } catch(e) { console.log("Method 1 Error: " + e); }
            try { console.log("Method 2 (.length):      " + debugServer.trackedNotifications.length); } catch(e) { console.log("Method 2 Error: " + e); }
            try { console.log("Method 3 (.rowCount()):  " + debugServer.trackedNotifications.rowCount()); } catch(e) { console.log("Method 3 Error: " + e); }
            try { console.log("Method 4 (keys dump):    " + Object.keys(debugServer.trackedNotifications).join(", ")); } catch(e) { console.log("Method 4 Error: " + e); }
        }
    }
}