// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken}
})

// Theme persistence across LiveView navigations and server events
window.addEventListener("phx:set-theme", (e) => {
  const mode = e.detail?.theme || e.target?.dataset?.phxTheme
  if (!mode) return
  if (mode === "system") {
    localStorage.removeItem("phx:theme")
    const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches
    document.documentElement.setAttribute("data-theme", prefersDark ? "dark" : "light")
    document.documentElement.setAttribute("data-theme-mode", "system")
  } else {
    localStorage.setItem("phx:theme", mode)
    document.documentElement.setAttribute("data-theme", mode)
    document.documentElement.setAttribute("data-theme-mode", mode)
  }
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#2563eb"}, shadowColor: "rgba(0, 0, 0, .25)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
