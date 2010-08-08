package com.kaltura.kdpfl.plugin.component {

	
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.events.TimerEvent;
	import flash.net.URLRequest;
	import flash.net.navigateToURL;
	import flash.utils.Timer;
	
	import org.osmf.elements.ProxyElement;
	import org.osmf.elements.beaconClasses.Beacon;
	import org.osmf.events.LoaderEvent;
	import org.osmf.events.MediaErrorEvent;
	import org.osmf.media.MediaElement;
	import org.osmf.media.MediaFactory;
	import org.osmf.media.URLResource;
	import org.osmf.traits.LoadState;
	import org.osmf.utils.HTTPLoader;
	import org.osmf.vast.loader.VASTLoadTrait;
	import org.osmf.vast.loader.VASTLoader;
	import org.osmf.vast.media.CompanionElement;
	import org.osmf.vast.media.VASTMediaGenerator;
	import org.osmf.vast.model.VASTDataObject;
	import org.osmf.vast.model.VASTUrl;
	import org.osmf.vast.parser.base.VAST2CompanionElement;
	import org.puremvc.as3.patterns.proxy.Proxy;
	
	public class VastLinearAdProxy extends Proxy
	{
		
		private var _mediaFactory : MediaFactory;
		private var _prerollUrl : String;
		private var _postrollUrl : String;
		private var _playingAd : MediaElement;
		private var _playingAdClickThru : String; //Uniform click-thru url for VAST linear ad
		private var _playingAdClickTrackings : Array; // Uniform tracking event urls for ad click-thru
		private var _companionAds : Array = new Array();
		private var _vastElements : Vector.<MediaElement>; 
		private var companionAds : VastCompanionAdProxy;
		
		private var _loadTimeout : Number;
		private var _loadTimer : Timer;
		
		private var _vastLoader : VASTLoader = new VASTLoader(MAX_NUM_REDIRECTS);

		/**
		 * Constructor.
		 * @param prerollUrl
		 * @param postrollUrl
		 * @param flashCompanions
		 * @param htmlCompanions
		 *
		 */
		public function VastLinearAdProxy(prerollUrl:String, postrollUrl:String, flashCompanions:String, htmlCompanions:String, timeout:Number=0) {
			super();
			
			_prerollUrl = prerollUrl;
			_postrollUrl = postrollUrl;
			if(timeout && timeout >= 4)
			{
				_loadTimeout = timeout;
			}else{
				_loadTimeout = 4;
			}
			
			companionAds = new VastCompanionAdProxy(flashCompanions, htmlCompanions);

		}


		/**
		 *Initiate the load process of the ad - determine whether loading pre-roll or post-roll ad.
		 * @param context - signifies the context of the ad: "pre" for pre-roll and "post" for post-roll
		 *
		 */
		public function loadAd(context:String):void {
			var loadUrl : String;
			var timestamp : Number = new Date().time;
			if (context == "pre" && _prerollUrl) {
				loadUrl = _prerollUrl;
				if(_prerollUrl.indexOf(".xml") == -1)
					loadUrl = loadUrl + "&timestamp=" + timestamp;
			} else if (_postrollUrl){
				loadUrl = _postrollUrl;
				if(_postrollUrl.indexOf(".xml") == -1)
					loadUrl = loadUrl + "&timestamp=" + timestamp;
			}
			
			if(loadUrl)
			{
				loadLinearAd( loadUrl);
			}
		}


		/**
		 * Function initiates the load of ads
		 *
		 */
		private function loadLinearAd( url : String):void {
			var prerollVastResource:URLResource = new URLResource(url);
			
			var vastLoadTrait:VASTLoadTrait = new VASTLoadTrait(_vastLoader, prerollVastResource);
			_vastLoader.addEventListener(LoaderEvent.LOAD_STATE_CHANGE, onVastAdStateChange);
			companionAds.cleanMaps();
			
			_loadTimer = new Timer(_loadTimeout*1000, 1);
			_loadTimer.addEventListener(TimerEvent.TIMER_COMPLETE, onLoadTimeout);
			_loadTimer.start();
			_vastLoader.load(vastLoadTrait);
		}


		/**
		 * Function handles the situation where a VAST ad has failed to load within the desired time frame 
		 * @param e
		 * 
		 */		
		private function onLoadTimeout (e: TimerEvent) : void
		{
			if (_vastLoader.hasEventListener(LoaderEvent.LOAD_STATE_CHANGE) )
			{
				_vastLoader.removeEventListener(LoaderEvent.LOAD_STATE_CHANGE, onVastAdStateChange );
			}
			_loadTimer.stop();
			_loadTimer.removeEventListener(TimerEvent.TIMER_COMPLETE,onLoadTimeout);
			signalEnd();
		}
		/**
		 * Listener function for chnage in the vast load state
		 * @param e
		 *
		 */
		private function onVastAdStateChange(e:LoaderEvent):void {
			if (e.newState == LoadState.READY) {
				//Stop the timeout timer, as the ad has already loaded.
				_loadTimer.stop();
				_loadTimer.removeEventListener(TimerEvent.TIMER_COMPLETE, onLoadTimeout );
				
				var vastMediaGenerator:VASTMediaGenerator = new VASTMediaGenerator(null, _mediaFactory);

				_vastElements = vastMediaGenerator.createMediaElements((e.loadTrait as VASTLoadTrait).vastDocument);
				 companionAds.createFlashCompanionsMap((e.loadTrait as VASTLoadTrait).vastDocument);
				 companionAds.createHtmlCompanionMap((e.loadTrait as VASTLoadTrait).vastDocument);
				
				for each(var mediaElement : MediaElement in _vastElements)
				{
					if (mediaElement is ProxyElement)
					{

						_playingAd = mediaElement;
					}
					if (mediaElement is CompanionElement) {
						_companionAds.push(mediaElement as VAST2CompanionElement);
					}

				}
				if (_playingAd) {
					parseVideoClicks ((e.loadTrait as VASTLoadTrait).vastDocument);
					playAd();
					companionAds.displayFlashCompanions(facade);
					companionAds.displayHtmlCompanions(facade);
				}
				else
				{
					//In case the ad has no playable media element.
					trace ("unable to play ad");
					signalEnd();
				}
			//In case there was an error parsing or loading the VAST xml
			} else if (e.newState == LoadState.LOAD_ERROR) {
				//Stop the timeout timer
				_loadTimer.stop();
				_loadTimer.removeEventListener(TimerEvent.TIMER_COMPLETE, onLoadTimeout );
				
				
				trace("error loading ad");
				signalEnd();
			}
		}


		/**
		 *Change the media playing in the media player to the vast media and start playing.
		 *
		 */
		private function playAd():void 
		{
			var playerMediator:Object = facade.retrieveMediator("kMediaPlayerMediator");
			playerMediator["player"].addEventListener(MediaErrorEvent.MEDIA_ERROR, onVastAdError);
			playerMediator["cleanMedia"]();
			_playingAd.addEventListener("traitAdd", onAdPlayable);
			playerMediator["player"]["media"] = _playingAd;
			var sequenceProxy : Object = facade.retrieveProxy("sequenceProxy");
			
			if (_playingAdClickThru) {
				playerMediator["kMediaPlayer"].addEventListener(MouseEvent.CLICK, onAdClick);
			}
			//playerMediator.player.addEventListener(TimeEvent.COMPLETE, onAdComplete);
			//playerMediator["playContent"]();
			//TODO track stats
			sendNotification("adStart",
							 {timeSlot: getContextString(sequenceProxy["sequenceContext"])});
		}
		
		//Once the ad mediaElement has a time trait, it is safe to show the notice message.
		private function onAdPlayable (e:Event) : void
		{
			var sequenceProxy : Object = facade.retrieveProxy("sequenceProxy");
			var playerMediator : Object = facade.retrieveMediator("kMediaPlayerMediator");
			if (e["traitType"] == "time" && sequenceProxy["sequenceContext"] != "post")
			{
				sequenceProxy["vo"]["isAdLoaded"] = true;
			}
			else if (e["traitType"] == "play")
			{
				playerMediator["playContent"]();
			}
		}

		/**
		 * selects the context name to be dispatched for statistics plugin.
		 * @param str	context const (SequenceContextType)
		 * @return 		context string
		 */
		private function getContextString(str:String):String {
			var res:String;
			switch (str) {
				case "pre":
					res = "preroll";
					break;
				case "mid":
					res = "midroll";
					break;
				case "post":
					res = "postroll";
					break;
			}
			return res;
		}


		private function onAdClick(e:MouseEvent):void {
			var urlReq:URLRequest = new URLRequest(_playingAdClickThru);
			navigateToURL(urlReq);
			for (var i:int=0; i<_playingAdClickTrackings.length; i++)
			{
				var beacon : Beacon = new Beacon(_playingAdClickTrackings[i], new HTTPLoader() );
				beacon.ping();
			}
			//var clickTrackingUrl : String = ((e.target as KMediaPlayer).player.media as VASTTrackingProxyElement).
			//TODO track stats
			var sequenceProxy:Proxy = facade.retrieveProxy("sequenceProxy") as Proxy;
			sendNotification("adClick",
							 {timeSlot: getContextString(sequenceProxy["sequenceContext"])});
		}



		/**
		 * Listener for and error in the playing process of the ad.
		 * @param e
		 *
		 */
		private function onVastAdError(e:MediaErrorEvent):void {
			trace("A problem occured when playing this ad : " + e.error);
			signalEnd();
		}


		/**
		 * Function parses the link of the video clickthru from the Vast document
		 * @param vastDoc
		 *
		 */
		private function parseVideoClicks(vastDoc:VASTDataObject):void {
			_playingAdClickThru = null;
			_playingAdClickTrackings = null;
			if (vastDoc.vastVersion == 2) {
				if (vastDoc["clickThruUrl"]) {
					_playingAdClickThru = vastDoc["clickThruUrl"];
					_playingAdClickTrackings = new Array();
					if (vastDoc["trkClickThruEvent"][0])
					{
						for (var i:int=0; i<(vastDoc["trkClickThruEvent"][0]["url"] as XMLList).length(); i++)
						{
							_playingAdClickTrackings.push(vastDoc["trkClickThruEvent"][0]["url"][i].toString());
						}
					}
				}
			} else if (vastDoc.vastVersion == 1) {
				if (vastDoc["ads"].length > 0) {
					if (vastDoc["ads"][0].inlineAd) {
						if (vastDoc["ads"][0].inlineAd.video) {
							if (vastDoc["ads"][0].inlineAd.video.videoClick) {
								_playingAdClickThru = vastDoc["ads"][0].inlineAd.video.videoClick.clickThrough ? vastDoc["ads"][0].inlineAd.video.videoClick.clickThrough.url : null;
								_playingAdClickTrackings = vastDoc["ads"][0].inlineAd.video.videoClick.clickTrackings ? constructClickTrackings (vastDoc["ads"][0].inlineAd.video.videoClick.clickTrackings) : null;
							}
						}
					}
				}
			}
		}
		
		private function constructClickTrackings ( vast1ClickTrackings : Vector.<VASTUrl> ) : Array
		{
			var clickTrackings : Array = new Array();
			for (var i:int = 0; i<vast1ClickTrackings.length; i++)
			{
				clickTrackings.push(vast1ClickTrackings[i]["url"]);
			}
			return clickTrackings;
		}

		//Public functions
		//todo: check if skip ad also does this function

		public function removeClickThrough():void {
			var playerMediator:Object = facade.retrieveMediator("kMediaPlayerMediator");
			if (playerMediator["kMediaPlayer"].hasEventListener(MouseEvent.CLICK)) {
				playerMediator["kMediaPlayer"].removeEventListener(MouseEvent.CLICK, onAdClick);
				_playingAdClickThru = null;
			}
		}


		/**
		 * This function dispatches a notification signifying that the vast component has finished playing. 
		 * Used when the vast load trait has encountered a problem and the VAST was never loaded
		 */		
		public function signalEnd () : void
		{
			removeClickThrough();
			sendNotification("enableGui", {guiEnabled : true, enableType : "full"});
			sendNotification("sequenceItemPlayEnd");
		}


		/**
		 * Function removes the vast clickthrough, hides the companion ads and enables the GUI.
		 * Used when the VAST video ads (linear ads) have finished playing.
		 */		
		public function resetVast () : void
		{
			removeClickThrough();
			companionAds.hideFlashCompanionAds(facade);
			
		}


		/**
		 *Getter for the ad playing in the player
		 * @return
		 *
		 */
		public function get playingAd():MediaElement {
			return _playingAd;
		}
		
		//When setting both the pre-roll and the post-roll url, it is important to add the time stamp parameter to avoid caching of the url.
		
		public function set prerollUrl(value:String):void
		{
			var timestamp : Number = new Date().time;
			_prerollUrl = value;
			
		}

		public function set postrollUrl(value:String):void
		{
			var timestamp : Number = new Date().time;
			_postrollUrl = value;
			
		}


		private static const MAX_NUM_REDIRECTS:Number = 5;
	}
}