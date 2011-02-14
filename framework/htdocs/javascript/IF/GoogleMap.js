// This allows us to represent a component
// on the client side with a javascript
// client.

// ---- constructor ----
GoogleMap = IF.extend(IFFormComponent,function(uniqueId, bindingName) {
            this.uniqueId = uniqueId;
            this.bindingName = bindingName;
            this.element = jQuery('#'+uniqueId)[0];
            this.assets = new Array();
            this._markers = new Array();
            this._markerCount = 0;

            if (!this.element) {
                alert("Can't find element " + uniqueId);
            }
            this._mapElement = jQuery('#'+this.uniqueId + "-map")[0];
            if (!this._mapElement) {
                alert("Couldn't find map element");
            }
            if (GBrowserIsCompatible()) {
                this.setMap(new GMap2(jQuery(this._mapElement)[0]));
                this.map().setCenter(new GLatLng(0.0, 0.0), 1);
                this.map().addControl(new GSmallMapControl());
                this.map().addControl(new GMapTypeControl());
            }
        },
        {
        render: function() {
            if (typeof this.map() == undefined) {
                console.log("Couldn't find map");
                return;
            }

            var tries = 10;
            while (!this.map().isLoaded()) {
                console.log("Map is not yet loaded");
                return;
            }
            console.log("Foux da fa fa");

            for (var i=0; i<this._assets.length; i++) {
                this.lookupLatLngForItem(this._assets[i]);
                console.log("Looked up coords for item " + i);
            }
        },

        lookupLatLngForItem: function(item) {
            var foo = this; // this is for the closures used in the callbacks

            // if the item knows its lat and lon then use it
            if (item.mappingLatitude != "" && item.mappingLongitude != "") {
                var marker = foo.markerAtPointForItem(new GLatLng(item.mappingLatitude, item.mappingLongitude), item);
                foo.map().addOverlay(marker);
                foo.addMarker(marker);
                if (foo.map() && foo.map().isLoaded() && foo.shouldZoomMap()) {
                    foo.zoomMapToMarkers();

                    GEvent.addListener(foo.map(), "infowindowclose", function() {
                        foo.zoomMapToMarkers();
                    });
                }
                return;
            }

            // otherwise call up the google geocoder and ask it nicely.
            var gc = this._gClientGeoCoder();
            if (!gc) { console.log ("No google maps geocoder found!"); return; }

            gc.getLatLng(
                item.mappingAddress,
                    function(point) {
                        if (point) {
                            var marker = foo.markerAtPointForItem(point, item);
                            foo.map().addOverlay(marker);
                            foo.addMarker(marker);
                            if (foo.map() && foo.map().isLoaded() && foo.shouldZoomMap()) {
                                // console.log("zooming map to markers");
                                foo.zoomMapToMarkers();

                                GEvent.addListener(foo.map(), "infowindowclose", function() {
                                    foo.zoomMapToMarkers();
                                });
                            }
                        } else {
                            // add an empty marker
                            foo.addMarker();
                        }
                    }
            );
        },

        shouldZoomMap: function() {
            //console.log("assets length = " + this._assets.length + " and markers length is " + this._markerCount);
            if (this._assets.length == this._markerCount) {
                return true;
            }
            return false;
        },

        zoomMapToMarkers: function() {
            var bounds;

            for (var j=0; j<this._markers.length; j++) {
                if (!bounds) {
                    bounds = new GLatLngBounds(this._markers[j].getPoint());
                } else {
                    bounds.extend(this._markers[j].getPoint());
                }
            }

            this.setBounds(bounds);
        },

        setBounds: function(bounds) {
            this._bounds = bounds;
            var center = bounds.getCenter();
            this.map().setCenter(center);
            var zoomLevel = this.map().getBoundsZoomLevel(bounds);
            this.map().setZoom(zoomLevel);
        },

        bounds: function() {
            return this._bounds;
        },

        addMarker: function(m) {
            this._markerCount++;
            if (m) {
                this._markers[this._markers.length] = m;
            }
        },

        // we really should use DOM nodes instead of
        // building HTML like this, but for now it's ok.
        markerAtPointForItem: function(point, item) {
            var marker = new GMarker(point, this.iconForItem(item));
            // now add an event listener?
            GEvent.addListener(marker, "click", function() {
                var info = "";

                if (item.mappingViewerUrl) {
                    info = info + "<h2><a href='" + item.mappingViewerUrl + "'>" + item.mappingTitle + "</a></h2>"
                } else {
                    info = info + "<h2>" + item.mappingTitle + "</h2>"
                }

                info = info + "<textarea wrap='physical' cols='30' rows='3'>" + item.mappingDescription + "</textarea><br />";
                info = info + "<em>" + item.mappingAddress + "</em>";

                info = "<div class='map-info-window'>" + info + "</div>";

                marker.openInfoWindowHtml(info);
            });
            return marker;
        },

        iconForItem: function(item) {
            //If there were different icons for different asset types, here is the place you
            //would define them.
            //Note when going to expand you can use a Base class and pass it to GIcon constructor, and it will
            //inherit the properties.
            /*
            if (! this.icon) {
                this.icon = new GIcon();
                this.icon.image = '/images/gmaps/foo.png';
                this.icon.shadow = '/images/gmaps/fooShadow.png';
                this.icon.iconSize = new GSize(21, 35);
                this.icon.shadowSize = new GSize(43, 35);
                this.icon.iconAnchor = new GPoint(10, 35);
                this.icon.infoWindowAnchor = new GPoint(10, 2);
                this.icon.infoShadowAnchor = new GPoint(10, 2);
            }
            */
            return this.icon;
        },

        _gClientGeoCoder: function () {
            this._geoCoder = new GClientGeocoder();
            return this._geoCoder;
        },

        map: function() {
            return this._map;
        },

        setMap: function(value) {
            this._map = value;
        },

        assets: function() {
            return this._assets;
        },

        setAssets: function(value) {
            this._assets = value;
        }

    }
);
