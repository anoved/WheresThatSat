//
// Per https://developer.mozilla.org/en/DOM/element.addEventListener#Legacy_Internet_Explorer_and_attachEvent
// versions of Internet Explorer prior to IE9 (ie, all XP versions) do not understand .addEventListener and
// must be catered to with their own special little snowflake .attachEvent.
//
// Parameters:
//   theElement (element to attach event listener to)
//   theEvent (the type of event to listen for)
//   theListener (the function to be notified when the event occurs)
//
// Results:
//   theListener is invoked when theEvent occurs in theElement
//
function AddEventListenerToElement(theElement, theEvent, theListener) {
	if (theElement.addEventListener) {
		theElement.addEventListener(theEvent, theListener);
	} else if (theElement.attachEvent) {
		theElement.attachEvent(theEvent, theListener);
	}
}

//
// Transformation matrix filter for CSS rotation in older versions of MSIE.
//
// Parameters:
//   heading (degrees)
//
// Returns:
//   string value for filter: or -ms-filter:"" styles
// 
function MSIERotationFilter(heading) {
	var theta = heading * Math.PI * 2.0 / 360.0; // heading in radians
	var costheta = Math.cos(theta);
	var sintheta = Math.sin(theta);
	return 'progid:DXImageTransform.Microsoft.Matrix(M11='+ costheta + ',M12=' +
			(-1 * sintheta) + ',M21=' + sintheta + ',M22=' + costheta +
			',sizingMethod=\'auto expand\');';
}

//
// Parameters:
//   heading (degrees in range 0 <= heading <= 360)
//
// Returns:
//   string representation of heading as compass direction
//   per https://en.wikipedia.org/wiki/Boxing_the_compass
//
function HeadingToCompassDirection(heading) {
	if (heading >= 0 && heading < 5.62) return "north";
	else if (heading >= 5.62 && heading < 16.87) return "north by east";
	else if (heading >= 16.87 && heading < 28.12) return "north-northeast";
	else if (heading >= 28.12 && heading < 39.37) return "northeast by north";
	else if (heading >= 39.37 && heading < 50.62) return "northeast";
	else if (heading >= 50.62 && heading < 61.87) return "northeast by east";
	else if (heading >= 61.87 && heading < 73.12) return "east-northeast";
	else if (heading >= 73.12 && heading < 84.37) return "east by north";
	else if (heading >= 84.37 && heading < 95.62) return "east";
	else if (heading >= 95.62 && heading < 106.87) return "east by south";
	else if (heading >= 106.87 && heading < 118.12) return "east-southeast";
	else if (heading >= 118.12 && heading < 129.37) return "southeast by east";
	else if (heading >= 129.37 && heading < 140.62) return "southeast";
	else if (heading >= 140.62 && heading < 151.87) return "southeast by south";
	else if (heading >= 151.87 && heading < 163.12) return "south-southeast";
	else if (heading >= 163.12 && heading < 174.37) return "south by east";
	else if (heading >= 174.37 && heading < 185.62) return "south";
	else if (heading >= 185.62 && heading < 196.87) return "south by west";
	else if (heading >= 196.87 && heading < 208.12) return "south-southwest";
	else if (heading >= 208.12 && heading < 219.37) return "southwest by south";
	else if (heading >= 219.37 && heading < 230.62) return "southwest";
	else if (heading >= 230.62 && heading < 241.87) return "southwest by west";
	else if (heading >= 241.87 && heading < 253.12) return "west-southwest";
	else if (heading >= 253.12 && heading < 264.37) return "west by south";
	else if (heading >= 264.37 && heading < 275.62) return "west";
	else if (heading >= 275.62 && heading < 286.87) return "west by north";
	else if (heading >= 286.87 && heading < 298.12) return "west-northwest";
	else if (heading >= 298.12 && heading < 309.37) return "northwest by west";
	else if (heading >= 309.37 && heading < 320.62) return "northwest";
	else if (heading >= 320.62 && heading < 331.87) return "northwest by north";
	else if (heading >= 331.87 && heading < 343.12) return "north-northwest";
	else if (heading >= 343.12 && heading < 354.37) return "north by west";
	else if (heading >= 354.37 && heading <= 360) return "north";
}

//
// Parameters:
//   timestamp (Date object)
//
// Returns:
//   string representation of timestamp
//
function FormatTimestamp(timestamp) {
	return timestamp.toDateString() + ' at ' + timestamp.toTimeString();
}

//
// Parameters:
//   ll (array of floats; [0] is latitude, [1] is longitude)
//
// Returns:
//   string representation of ll
//
function FormatLatLon(ll) {
	var lat_hem = 'N';
	var lon_hem = 'E';
	if (ll[0] < 0) lat_hem = 'S';
	if (ll[1] < 0) lon_hem = 'W';
	return Math.abs(ll[0]).toString() + lat_hem + ' ' + Math.abs(ll[1]).toString() + lon_hem;
}

//
// Parameters:
//   coordinates (string of format "latitude,longitude")
//
// Returns:
//   array of floats; [0] is latitude, [1] is longitude
//
function CoordinateParameterToLatLon(coordinates) {
	var latlon_strings = coordinates.split(',');
	return Array(parseFloat(latlon_strings[0]), parseFloat(latlon_strings[1]));
}

//
// Parameters:
//   doc (HTML document containing the panel)
//   container (immediate parent element of panel)
//   caption (HTML content for panel)
//   id (id string for panel)
//
// Results:
//   creates div id as child of container with caption as content
//
// Returns:
//   panel div element
//
function CreateInfoPanel(doc, container, caption, id) {
	var infodiv = doc.createElement('div');
	infodiv.className = 'infopanel';
	infodiv.setAttribute('id', id + '-info');
	infodiv.innerHTML = caption;
	container.appendChild(infodiv);
	return infodiv;
}

//
// Parameters:
//   marker (map marker)
//   marker_content (map marker element to highlight)
//   panel (info element to highlight)
//
// Results:
//   adds mouseover/mouseout event listeners to marker and panel
//   that highlight marker_div and panel
//
function SetupMarkerPanelHighlights(marker, marker_content, panel) {
	
	var mouseover_function = function() {
			marker_content.style.borderColor = "#1A5CBF";
			panel.style.backgroundColor = "#FFFFAA";};
	var mouseout_function = function() {
			marker_content.style.borderColor = "transparent";
			panel.style.backgroundColor = "white";};
			
	// Marker mouseover/mouseout events
	google.maps.event.addListener(marker, 'mouseover', mouseover_function);
	google.maps.event.addListener(marker, 'mouseout', mouseout_function);
	
	// Panel mouseover/mouseout events
	AddEventListenerToElement(panel, 'mouseover', mouseover_function);
	AddEventListenerToElement(panel, 'mouseout', mouseout_function);
}

//
// Parameters:
//   info:
//     illumination
//     elevation
//     azimuth
//     solarelev
//     future (boolean)
//     satelliteName
//
// Returns:
//   caption string describing visibility from observer
// 
function FormatVisibilityCaption(info) {

	var caption = '';

	// Parse the additional observer-related information
	var illumination = parseInt(info.illumination, 10);
	var elevation = parseFloat(info.elevation);
	var azimuth = parseFloat(info.azimuth);
	var solarelev = parseFloat(info.solarelev);
	
	// technically, it may still be light out if solarelev < 0;
	// sunset/twilight lasts until solarelev < -6 or so
	if (illumination === 0 && elevation > 0 && solarelev < 0) {
		caption += '<p>' + info.satelliteName;
		if (info.future) caption += ' will <em>potentially</em> be';
		else caption += ' was <em>potentially</em>';
		caption +=  ' visible from the observer location at this time (elevation: ' + elevation + '&deg;, azimuth ' + azimuth + '&deg).</p>';
	} else {
		var waswillbe;
		caption += '<p>' + info.satelliteName;
		if (info.future) {
			caption += ' will probably <em>not</em> be';
			waswillbe = 'will be';
		} else {
			caption += ' was probably <em>not</em>';
			waswillbe = 'was';
		}
		caption += ' visible from the observer location at this time. (';
		var reasons = [];
		if (illumination !== 0) reasons.push('It ' + waswillbe + ' in the earth\'s shadow.');
		if (elevation <= 0) reasons.push('It ' + waswillbe + ' below the horizon.');
		if (solarelev >= 0) reasons.push('The sun ' + waswillbe + ' above the horizon.');
		caption += reasons.join(' ') + ')</p>';
	}
	
	return caption;
}

//
// Parameters:
//   v, a variable
//
// Returns:
//   false if v is undefined, otherwise true
//
function IsDefined(v) {
	if (typeof(v) === "undefined")
		return false;
	else
		return true;
}

//
// Parameters:
//   info:
//     altitude
//     heading
//     speed
//     coordinates
//     illumination
//     elevation
//     azimuth
//     solarelev
//     satelliteName
//     iconPath (relative to map page)
//     doc (HTML document)
//     map (Google Map)
//     container (for sidebar panels)
//     id (location descriptor)
//     captionIntro (text)
//     future (boolean)
//
// Results:
//   creates sat location map marker and corresponding info panel
//
function PlotSatelliteLocation(info) {
	
	// Parse basic information about the satellite at this position
	var altitude = parseFloat(info.altitude);
	var heading = parseFloat(info.heading);
	var direction = HeadingToCompassDirection(heading);
	var speed = parseFloat(info.speed);
	
	// Create the marker icon, rotated to match heading
	var icon_div = info.doc.createElement('div');
	icon_div.setAttribute('id', info.id + '-marker');
	icon_div.setAttribute('class', 'satmarker');
	var msie_rotation_filter = MSIERotationFilter(heading);
	icon_div.setAttribute('style',
			'-webkit-transform:rotate(' + heading + 'deg);' +
			'-moz-transform:rotate(' + heading + 'deg);' +
			'-o-transform:rotate(' + heading + 'deg);' +
			'-ms-transform:rotate(' + heading + 'deg);' +
			'transform:rotate(' + heading + 'deg);' + 
			'-ms-filter:"' + msie_rotation_filter + '";' +
			'filter:' + msie_rotation_filter + ';');
	var icon_img = info.doc.createElement('img');
	icon_img.setAttribute('src', info.iconPath);
	icon_div.appendChild(icon_img);
	
	// Create the map marker, using the created icon as content
	var ll = CoordinateParameterToLatLon(info.coordinates);
	var point = new google.maps.LatLng(ll[0], ll[1]);
	var marker = new RichMarker({
			position: point,
			clickable: false,
			draggable: false,
			anchor: RichMarkerPosition.MIDDLE,
			flat: true,
			map: info.map,
			content: icon_div});
	
	// Assemble the caption from basic information
	var caption = '<p><img id="' + info.id + '-icon" class="infoicon" src="' + info.iconPath + '">' +
			info.captionIntro + ' at an altitude of ' +	altitude + ' km above ' + FormatLatLon(ll) +
			', moving ' + direction + ' (' + heading + '&deg;) at ' + speed + ' km/s.</p>';
	
	// If observer information is available, append visibility note to caption
	if (IsDefined(info.illumination) && IsDefined(info.elevation) &&
			IsDefined(info.azimuth) && IsDefined(info.solarelev)) {
		caption += FormatVisibilityCaption({
				illumination: info.illumination,
				elevation: info.elevation,
				azimuth: info.azimuth,
				solarelev: info.solarelev,
				future: info.future,
				satelliteName: info.satelliteName});
	}
	
	// Display the caption in the sidebar
	var infopanel = CreateInfoPanel(document, info.container, caption, info.id);
	SetupMarkerPanelHighlights(marker, icon_div, infopanel);
	
	// Click icon in caption to pan to marker on map
	var infoicon = info.doc.getElementById(info.id + '-icon');
	AddEventListenerToElement(infoicon, 'click', function() {info.map.panTo(point);});
}

//
// Parameters:
//   map (basemap for plot)
//   coordinateParameters (array of strings of format "latitude,longitude")
//
// Results:
//   creates ground track polyline on map
//
// Returns:
//   LatLngBounds object representing extent of ground track
// 
function PlotGroundTrack(map, coordinateParameters) {
	var coordinateList = [];
	var extent = new google.maps.LatLngBounds();
	for (var i = 0; i < coordinateParameters.length; i++) {
		var coordinates = CoordinateParameterToLatLon(coordinateParameters[i]);
		var point = new google.maps.LatLng(coordinates[0], coordinates[1]);
		extent.extend(point);
		coordinateList.push(point);
	}
	var groundTrack = new google.maps.Polyline({
		path: coordinateList,
		strokeOpacity: 0.6,
		strokeWeight: 8,
		strokeColor: "#008800",
		geodesic: true,
		clickable: false,
		map: map});
	return extent;
}

//
// Parameters:
//   doc (HTML document for logo)
//   map (basemap for logo)
//
// Results:
//   displays WheresThatSat logo as a "control" on the map
//
// Returns:
//   div containing logo
//
function CreateLogoControl(doc, map) {
	var logoDiv = doc.createElement('div');
	logoDiv.setAttribute('id', 'logo');
	var logoImg = doc.createElement('img');
	logoImg.setAttribute('src', 'images/wheresthatsat.png');
	logoImg.setAttribute('alt', 'WheresThatSat Logo');
	logoDiv.appendChild(logoImg);
	map.controls[google.maps.ControlPosition.RIGHT_TOP].push(logoDiv);
	return logoDiv;
}

//
// Results:
//   creates base map and, if required parameters are present,
//   populates it with sat path, location markers, and other info
//		
function initialize() {
	
	// Page layout divs
	var map_canvas = document.getElementById("map_canvas");
	var rightpanel = document.getElementById("rightpanel");
	
	// Create the basemap. #1A5CBF
	var map = new google.maps.Map(map_canvas, {
			backgroundColor: "white",
			center: new google.maps.LatLng(0, 0),
			zoom: 2,
			mapTypeId: google.maps.MapTypeId.TERRAIN,
			panControl: true,
			zoomControl: true,
			mapTypeControl: true,
			scaleControl: true,
			streetViewControl: false,
			overviewMapControl: true,
			overviewMapControlOptions: {
				opened: false
			}});
	
	// Place the logo image on the map
	CreateLogoControl(document, map);
	
	q = new QueryString();
	
	// Don't bother proceeding if the basic info isn't available
	if (!q.exists('sn') || !q.exists('un') || !q.exists('ut'))
		return;
	
	var satelliteName = q.value('sn');
	var userName = q.value('un');
	var tweetID = q.value('ut');
		
	// Fundamental feature: ground track
	if (q.exists('ll') && q.exists('t1') && q.exists('t2')) {
		
		// Display the sidebar
		rightpanel.style.width = "250px";
		map_canvas.style.right = "250px";
		
		// Get the endpoints of the ground track	
		var traceStartTime = new Date(parseInt(q.value('t1'), 10) * 1000);
		var traceEndTime   = new Date(parseInt(q.value('t2'), 10) * 1000);
		
		// Plot the ground track on the map
		var traceExtent = PlotGroundTrack(map, q.values('ll'));

		// Assemble and display ground track description
		var tweetlink = 'https://twitter.com/' + userName + '/statuses/' + tweetID;
		var searchlink = 'http://nssdc.gsfc.nasa.gov/nmc/spacecraftSearch.do?spacecraft=' + escape(satelliteName);
		var caption = '<p>The green line depicts the ground track of <a href="' + searchlink + '">' + satelliteName + '</a> from ' + FormatTimestamp(traceStartTime) + ' to ' + FormatTimestamp(traceEndTime) + '.</p>';
		CreateInfoPanel(document, rightpanel, caption, 'trace');
	
		// Optional feature: observer position.
		if (q.exists('ol')) {
		
			// Plot the observer marker on the map
			var ol = CoordinateParameterToLatLon(q.value('ol'));
			var point = new google.maps.LatLng(ol[0], ol[1]);
			traceExtent.extend(point);
			var observerMarker = new google.maps.Marker({
					position: point,
					animation: google.maps.Animation.DROP,
					title: userName,
					icon: 'images/observer.png',
					clickable: false,
					map: map});
			
			// Assemble and display the observer description
			var obscaption = '<p><img id="observer-icon" class="infoicon" src="images/observer.png">';
			if (q.exists('on')) obscaption += 'The observer location is ' + FormatLatLon(ol) + ' (' + q.value('on') + ').</p>';
			else obscaption += 'The observer location is ' + FormatLatLon(ol) + '.</p>';
			var obsinfo = CreateInfoPanel(document, rightpanel, obscaption, 'observer');
			
			// Center map on observer marker if the description icon is clicked
			var obsinfoicon = document.getElementById('observer-icon');
			AddEventListenerToElement(obsinfoicon, 'click', function() {map.panTo(point);});
		}

		map.fitBounds(traceExtent);

		// Create marker to represent Mention position.
		if (q.exists('ml') && q.exists('ma') && q.exists('mh') && q.exists('ms') && q.exists('mt')) {
			
			// The absence of a response marker indicates that the
			// mention marker represents an explicitly specified time
			var no_response_marker = true;
			if (q.exists('rl') && q.exists('ra') && q.exists('rh') && q.exists('rs') && q.exists('rt'))
				no_response_marker = false;
			
			// Set page title to mention satellite name
			document.title = "Where's That Sat: " + satelliteName;
			
			// Assemble wording for description introduction.
			// Three cases: specific future time, specific past time,
			// or implicit past time (that of the mentioning tweet)
			var timestamp = new Date(parseInt(q.value('mt'), 10) * 1000);
			var intro = '';
			var future = false;
			if (no_response_marker) {
				intro = 'You <a href="' + tweetlink + '">mentioned</a> ' + satelliteName + '. On ' + FormatTimestamp(timestamp) + ', it ';
				if (timestamp > Date.now()) {
					intro += 'will be';
					future = true;
				} else intro += 'was';
			} else {
				intro = 'When you <a href="' + tweetlink + '">mentioned</a> ' + satelliteName + ' on ' + FormatTimestamp(timestamp) + ', it was';
			}
			
			// Fling a bunch of parameters at the map and see what sticks!
			PlotSatelliteLocation({
					altitude: q.value('ma'),
					heading: q.value('mh'),
					speed: q.value('ms'),
					coordinates: q.value('ml'),
					illumination: q.value('mi'),
					elevation: q.value('me'),
					azimuth: q.value('mz'),
					solarelev: q.value('mo'),
					satelliteName: satelliteName,
					iconPath: 'images/a.png',
					doc: document,
					map: map,
					container: rightpanel,
					id: 'mention',
					captionIntro: intro,
					future: future});
					
			// Create marker to represent Reply position, if specified.
			if (!no_response_marker) {
				var rtimestamp = new Date(parseInt(q.value('rt'), 10) * 1000);
				var rintro = 'When @WheresThatSat replied on ' + FormatTimestamp(rtimestamp) + ', ' + satelliteName + ' was';
				PlotSatelliteLocation({
					altitude: q.value('ra'),
					heading: q.value('rh'),
					speed: q.value('rs'),
					coordinates: q.value('rl'),
					illumination: q.value('ri'),
					elevation: q.value('re'),
					azimuth: q.value('rz'),
					solarelev: q.value('ro'),
					satelliteName: satelliteName,
					iconPath: 'images/b.png',
					doc: document,
					map: map,
					container: rightpanel,
					id: 'reply',
					captionIntro: rintro,
					future: false});
			}
		
		}
		
		// Prompt user to ask about this satellite again
		var askcaption = '<p><a href="https://twitter.com/intent/tweet?text=' + escape('@WheresThatSat ' + satelliteName) + '">Where\'s this sat now?</a> <img src="images/tweet-reply.png" /></p>';
		CreateInfoPanel(document, rightpanel, askcaption, 'ask');
		
		// View at other sites
		if (q.exists('si')) {
			var otherCaption = '<p><a href="http://n2yo.com/?s=' + escape(q.value('si')) + '">View current position at NY2O&hellip;</a></p>';
			CreateInfoPanel(document, rightpanel, otherCaption, 'other');
		}
		
		// Display referrer link iff it's a t.co shortlink
		if ((document.referrer !== '') && (document.referrer.split('/')[2] === 't.co')) {
			var refcaption = '<p>Link to this map page: <a href="' + document.referrer + '">' + document.referrer + '</a></p>';
			CreateInfoPanel(document, rightpanel, refcaption, 'referrer');
		}
	
	}
}
