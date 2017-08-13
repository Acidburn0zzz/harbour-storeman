import QtQuick 2.0
import Sailfish.Silica 1.0
import MeeGo.Connman 0.2
import org.nemomobile.notifications 1.0
import org.nemomobile.dbus 2.0
import harbour.orn 1.0
import "pages"

ApplicationWindow
{
    readonly property bool userAuthorised: ornClient && ornClient.authorised
    property bool repoFetching: true
    property bool _showUpdatesNotification: true

    initialPage: Component { RecentAppsPage { } }
    cover: Qt.resolvedUrl("cover/CoverPage.qml")
    allowedOrientations: defaultAllowedOrientations

    // This signal is emitting before gui ready
    Component.onCompleted: ornZypp.fetchRepos()

    Connections {
        target: __quickWindow
        onClosing: authorisationWarning.close()
    }

    NetworkManager {
        id: networkManager
    }

    Notification {

        function show(message, icn) {
            replacesId = 0
            previewSummary = ""
            previewBody = message
            icon = icn
            publish()
        }

        function showPopup(title, message, icn) {
            replacesId = 0
            previewSummary = title
            previewBody = message
            icon = icn
            publish()
        }

        id: notification
        expireTimeout: 3000
    }

    DBusAdaptor {
        service: "harbour.storeman.service"
        iface: "harbour.storeman.service"
        path: "/harbour/storeman/service"
        xml: "  <interface name=\"harbour.storeman.service\">\n" +
             "    <method name=\"loginPage\"/>\n" +
             "    <method name=\"installedAppsPage\"/>\n" +
             "  </interface>\n"

        function loginPage() {
            __silica_applicationwindow_instance.activate()
            pageStack.push(Qt.resolvedUrl("pages/AuthorisationDialog.qml"))
        }

        function installedAppsPage() {
            _showUpdatesNotification = false
            __silica_applicationwindow_instance.activate()
            pageStack.push(Qt.resolvedUrl("pages/InstalledAppsPage.qml"))
        }
    }

    Notification {
        id: authorisationWarning
        appIcon: "image://theme/icon-lock-warning"
        remoteActions: [ {
                name: "default",
                service: "harbour.storeman.service",
                path: "/harbour/storeman/service",
                iface: "harbour.storeman.service",
                method: "loginPage"
            } ]
    }

    OrnClient {
        id: ornClient
        onAuthorisedChanged: authorised ?
                                 //% "You have successfully logged in to the OpenRepos.net"
                                 notification.show(qsTrId("orn-loggedin-message")) :
                                 //% "You have logged out from the OpenRepos.net"
                                 notification.show(qsTrId("orn-loggedout-message"))
        onAuthorisationError: notification.showPopup(
                                  //% "Login error"
                                  qsTrId("orn-login-error-title"),
                                  //% "Could not log in the OpenRepos.net - check your credentials and network connection"
                                  qsTrId("orn-login-error-message"),
                                  "image://theme/icon-lock-warning")
        onDayToExpiry: {
            //% "Authorisation expires"
            authorisationWarning.previewSummary = qsTrId("orn-authorisation-expires-summary")
            //% "Click to reauthorise"
            authorisationWarning.previewBody = qsTrId("orn-reauthorise")
            //% "The OpenRepos authorisation expires. Click to reauthorise."
            authorisationWarning.body = qsTrId("orn-authorisation-expires-body")
            authorisationWarning.publish()
        }
        onCookieIsValidChanged: if (!cookieIsValid) {
            //% "Authorisation expired"
            authorisationWarning.previewSummary = qsTrId("orn-authorisation-expired-summary")
            authorisationWarning.previewBody = qsTrId("orn-reauthorise")
            //% "The OpenRepos authorisation has expired. Click to reauthorise."
            authorisationWarning.body = qsTrId("orn-authorisation-expired-body")
            authorisationWarning.publish()
        }
        onBookmarkChanged: {
            notification.show(bookmarked ?
                                  //% "The app was added to bookmarks"
                                  qsTrId("orn-bookmarks-added") :
                                  //% "The app was removed from bookmarks"
                                  qsTrId("orn-bookmarks-removed"))
        }
    }

    Notification {
        id: updatesNotification
        appIcon: "image://theme/icon-lock-application-update"
        //% "Updates available"
        previewSummary: qsTrId("orn-updates-available-summary")
        //% "Click to view updates"
        previewBody: qsTrId("orn-updates-available-preview")
        //% "Applications updates are available. Click to view details."
        body: qsTrId("orn-updates-available-body")
        remoteActions: [ {
                name: "default",
                service: "harbour.storeman.service",
                path: "/harbour/storeman/service",
                iface: "harbour.storeman.service",
                method: "installedAppsPage"
            } ]

        Component.onCompleted: {
            var uid = ornClient.value("gui/update_notification_id")
            if (uid !== undefined) {
                replacesId = uid
            }
        }

        onClosed: ornClient.setValue("gui/update_notification_id", undefined)
    }

    Connections {
        target: ornZypp
        onUpdatesAvailableChanged: {
            // Don't show notification if
            // the app was openned from notification
            if (ornZypp.updatesAvailable) {
                if (_showUpdatesNotification) {
                    updatesNotification.publish()
                    ornClient.setValue("gui/update_notification_id", updatesNotification.replacesId)
                }
            } else {
                updatesNotification.close()
            }
            _showUpdatesNotification = true
        }
        onBeginRepoFetching: {
            repoFetching = true
            //% "Reading the repositories data"
            notification.show(qsTrId("orn-reading-repos-begin"),
                              "image://theme/icon-s-high-importance")
        }
        onEndRepoFetching: {
            repoFetching = false
            //% "Finished reading the repositories data"
            notification.show(qsTrId("orn-reading-repos-end"),
                              "image://theme/icon-s-installed")
        }
    }
}
