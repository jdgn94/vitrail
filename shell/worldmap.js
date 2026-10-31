// World-map maths for the Date & time page: equirectangular projection, zoom
// and pan, the zone under the pointer, search and labels. Pure.
//
// A `view` is { zoom, ox, oy }: the map is `width * zoom` pixels wide (twice
// as wide as tall) and its top-left corner sits at (ox, oy) in the viewport.
// A zone is { id, lat, lon, offset (minutes from UTC), note }.
.pragma library

var maxZoom = 12

function project(lon, lat, width) {
    return { x: (lon + 180) / 360 * width, y: (90 - lat) / 180 * width / 2 }
}

function unproject(x, y, width) {
    return { lon: x / width * 360 - 180, lat: 90 - y / (width / 2) * 180 }
}

// Where a place is in the viewport.
function screenOf(place, view, width) {
    var point = project(place.lon, place.lat, width * view.zoom)
    return { x: point.x + view.ox, y: point.y + view.oy }
}

// The map always covers the viewport: no empty margin when zoomed in.
function clamp(view, width, height) {
    var mapWidth = width * view.zoom
    var mapHeight = mapWidth / 2
    return {
        zoom: view.zoom,
        ox: Math.max(Math.min(0, width - mapWidth), Math.min(0, view.ox)),
        oy: Math.max(Math.min(0, height - mapHeight), Math.min(0, view.oy))
    }
}

// Zooms to `zoom` keeping the point under (px, py) where it is.
function zoomAbout(view, zoom, px, py, width, height) {
    var next = Math.max(1, Math.min(maxZoom, zoom))
    var ratio = next / view.zoom
    return clamp({ zoom: next, ox: px - (px - view.ox) * ratio, oy: py - (py - view.oy) * ratio },
                 width, height)
}

function centerOn(lon, lat, zoom, width, height) {
    var point = project(lon, lat, width * zoom)
    return clamp({ zoom: zoom, ox: width / 2 - point.x, oy: height / 2 - point.y }, width, height)
}

// The zone closest to (px, py), at most `radius` pixels away, or null.
function nearest(zones, view, width, px, py, radius) {
    var best = null
    var bestDistance = radius * radius
    for (var i = 0; i < zones.length; i++) {
        var at = screenOf(zones[i], view, width)
        var distance = (at.x - px) * (at.x - px) + (at.y - py) * (at.y - py)
        if (distance <= bestDistance) {
            best = zones[i]
            bestDistance = distance
        }
    }
    return best
}

function find(zones, id) {
    for (var i = 0; i < zones.length; i++) {
        if (zones[i].id === id)
            return zones[i]
    }
    return null
}

// "America/Argentina/Buenos_Aires": city "Buenos Aires", region "America / Argentina".
function city(id) {
    return id.substring(id.lastIndexOf("/") + 1).replace(/_/g, " ")
}

function region(id) {
    var cut = id.lastIndexOf("/")
    return cut < 0 ? "" : id.substring(0, cut).replace(/_/g, " ").replace(/\//g, " / ")
}

function offsetLabel(minutes) {
    if (minutes === 0)
        return "UTC"
    var size = Math.abs(minutes)
    var hours = Math.floor(size / 60)
    var rest = size % 60
    return "UTC" + (minutes < 0 ? "-" : "+") + (hours < 10 ? "0" : "") + hours + ":" + (rest < 10 ? "0" : "") + rest
}

// "HH:mm" in a zone, given its offset and the instant in milliseconds.
function localTime(minutes, now) {
    var shifted = new Date(now + minutes * 60000)
    var hours = shifted.getUTCHours()
    var rest = shifted.getUTCMinutes()
    return (hours < 10 ? "0" : "") + hours + ":" + (rest < 10 ? "0" : "") + rest
}

function plain(text) {
    var lower = text.toLowerCase()
    return lower.normalize ? lower.normalize("NFD").replace(/[̀-ͯ]/g, "") : lower
}

// Zones whose city, region or note contain every word of the query, the ones
// whose city starts with the first word before the rest; no query lists all.
function search(zones, query) {
    var words = plain(query).split(/\s+/).filter(function (word) { return word !== "" })
    var ranked = []
    for (var i = 0; i < zones.length; i++) {
        var zone = zones[i]
        var name = plain(city(zone.id))
        var text = name + " " + plain(region(zone.id)) + " " + plain(zone.note || "")
        var fits = words.every(function (word) { return text.indexOf(word) >= 0 })
        if (!fits)
            continue
        var rank = words.length === 0 || name.indexOf(words[0]) === 0 ? 0
                   : name.indexOf(words[0]) > 0 ? 1 : 2
        ranked.push({ zone: zone, rank: rank, name: name })
    }
    ranked.sort(function (a, b) {
        return a.rank - b.rank || (a.name < b.name ? -1 : a.name > b.name ? 1 : 0)
    })
    return ranked.map(function (entry) { return entry.zone })
}
