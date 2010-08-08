﻿/**
 * ScrubberMediator
 *
 * @langversion 3.0
 * @playerversion Flash 9.0.28.0
 * @author Dan X Bacon		baconoppenheim.com
 */
 package com.kaltura.kdpfl.view.controls
{
	
import com.kaltura.kdpfl.model.ConfigProxy;
import com.kaltura.kdpfl.model.type.NotificationType;

import flash.events.Event;

import org.puremvc.as3.interfaces.INotification;
import org.puremvc.as3.patterns.mediator.Mediator;


public class ScrubberMediator extends Mediator
{
	public static const NAME:String = "scrubberMediator";
	
	protected static const STATE_READY:String 		= "ready";
	protected static const STATE_NOT_READY:String	= "notReady";
	protected static const STATE_PLAYING:String		= "playing";
	protected static const STATE_PAUSED:String		= "paused";
	protected static const STATE_SEEKING:String		= "seeking";

	private var _state:String = STATE_NOT_READY;
	private var _prevState:String = STATE_NOT_READY;
	
	private var _bytesLoaded:Number = 0;
	private var _bytesTotal:Number = 0;
    private var _flashvars:Object;
    private var _isLiveRtmp:Boolean=false;
 
	 
	public function ScrubberMediator( viewComponent:Object=null )
	{
		super( NAME, viewComponent );
		//if ()
		scrubber.enabled = false;
		
		var configProxy : ConfigProxy = facade.retrieveProxy( ConfigProxy.NAME ) as ConfigProxy;
		_flashvars = configProxy.vo.flashvars;

		scrubber.addEventListener( KScrubber.EVENT_SEEK, onSeek, false, 0, true );
		scrubber.addEventListener( KScrubber.EVENT_SEEK_START, onSeekStart, false, 0, true );
		scrubber.addEventListener( KScrubber.EVENT_SEEK_END, onSeekEnd, false, 0, true );
		scrubber.addEventListener( KScrubber.EVENT_DRAG, onStartDrag, false, 0, true );
		scrubber.addEventListener( KScrubber.EVENT_DRAG_END, onEndDrag, false, 0, true );
	}

	private function onStartDrag( evt:Event ):void
	{
		sendNotification( NotificationType.SCRUBBER_DRAG_START );
	}
	private function onEndDrag( evt:Event ):void
	{
		sendNotification( NotificationType.SCRUBBER_DRAG_END);
	}
	private function onSeekStart( evt:Event ):void
	{
		_prevState = _state;
		_state = STATE_SEEKING;
		sendNotification( NotificationType.DO_PAUSE );
	}

	private function onSeek( evt:Event ):void
	{
		var seekPosition:Number = scrubber.getPosition();
		sendNotification( NotificationType.DO_SEEK, seekPosition );
	}
	
	private function onSeekEnd( evt:Event ):void
	{
		if( _prevState == STATE_PLAYING )
		{
			//trace( "DO_PLAY" );
			sendNotification( NotificationType.DO_PLAY );
			_prevState = STATE_PLAYING;
		}		
	}
		
	override public function handleNotification( note:INotification ):void
	{	
		switch( note.getName() )
		{
			case NotificationType.KDP_READY:
				_state = STATE_READY;
			break;
		
			case NotificationType.PLAYER_PLAYED:
				_state = STATE_PLAYING;
				
				
			break;

			case NotificationType.PLAYER_PAUSED:
				_state = STATE_PAUSED;
			break;
				
			case NotificationType.PLAYER_UPDATE_PLAYHEAD:
				var position:Number = note.getBody() as Number;
				scrubber.setPosition( position );
			break;

			case NotificationType.DURATION_CHANGE:
				var duration:Number = note.getBody().newValue;
				scrubber.duration = duration;
			break;
			
			case NotificationType.BYTES_TOTAL_CHANGE:
				_bytesTotal = note.getBody().newValue ; 
				trace("butes total: ", _bytesTotal)
			break;

			case NotificationType.BYTES_DOWNLOADED_CHANGE:
				_bytesLoaded = note.getBody().newValue;
				var loadProgress:Number = _bytesLoaded/_bytesTotal;
				scrubber.setLoadProgress( loadProgress );
			break;

		}
	}
	
	override public function listNotificationInterests():Array
	{
		return [
				NotificationType.KDP_READY,
				NotificationType.PLAYER_PLAYED,
				NotificationType.PLAYER_PAUSED,
				NotificationType.PLAYER_UPDATE_PLAYHEAD,
				NotificationType.DURATION_CHANGE,
				NotificationType.BYTES_TOTAL_CHANGE,
				NotificationType.BYTES_DOWNLOADED_CHANGE
			   ];
	}
			
	public function get scrubber():KScrubber
	{
		return( viewComponent as KScrubber );
	}		
}
}