package com.kaltura.kdpfl.plugin.component
{
	//import com.kaltura.kdpfl.component.IComponent;
	import com.kaltura.kdpfl.view.controls.KButton;
	import com.yahoo.astra.fl.controls.TabBar;
	
	import fl.data.DataProvider;
	
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.geom.Rectangle;
	
	
	public class TabBarKdp3 extends Sprite //implements IComponent
	{
		public var tabBar:TabBar; 
		private var tabData:Array;
		public var prevBut:KButton = new KButton();
		public var nextBut:KButton = new KButton();
		public var padding:Number = 5;
		private var localProvider:DataProvider = null;
		private var firstVisibleButton:int= 0;
		private var needToMove:Number = 0; 
		
		public function TabBarKdp3() 
		{		
			onComplete(null);
			prevBut.label = "";
			prevBut.buttonMode = true;
			prevBut.useHandCursor = true;
			prevBut.move(0, 0);
			prevBut.addEventListener(MouseEvent.CLICK, onPrevClicked);
			addChild(prevBut);	
			
			nextBut.label = "";
			nextBut.buttonMode = true;
			nextBut.useHandCursor = true;
			nextBut.addEventListener(MouseEvent.CLICK, onNextClicked);
			addChild(nextBut);	

			nextBut.visible = false;
			prevBut.visible = false;	
			
		}
		
		private function onNextClicked(event:MouseEvent):void {
			var j:int = 0;
			var currWidth:int = 0;
			var rect:Rectangle = this.tabBar.scrollRect;
			
			//if last button to scroll then stop
			if (firstVisibleButton == this.tabBar.numChildren) return;
			
			//If there is enough space to show all buttons then stopm
			for (j=firstVisibleButton; j < this.tabBar.numChildren; j++)	
			{
				currWidth += this.tabBar.getChildAt(j).width;
			}
			if (currWidth < rect.width) return;
			
			//Otherwise scroll one button a time
			firstVisibleButton = firstVisibleButton +1;
			rect.x = 0;
			for (j=0; j < firstVisibleButton && j < this.tabBar.numChildren; j++)
			{
				rect.x += this.tabBar.getChildAt(j).width;				
			} 
			this.tabBar.scrollRect = rect;
		}

		private function onPrevClicked(event:MouseEvent):void 
		{
			var j:int = 0;
			var rect:Rectangle = this.tabBar.scrollRect;
			
			//if first button to scroll then stop
			if (firstVisibleButton == 0) return;
			
			firstVisibleButton = firstVisibleButton - 1;
			rect.x = 0;
			for (j=0; j < firstVisibleButton && j < this.tabBar.numChildren; j++)
			{
				rect.x += this.tabBar.getChildAt(j).width;				
			} 
			this.tabBar.scrollRect = rect;
		}

		private function onComplete(ev:Event):void
		{
			this.tabBar = new TabBar(); 
			tabBar.useHandCursor = true;
			tabBar.mouseChildren = true;
			tabBar.buttonMode = true;
			if (localProvider != null)
			{
				this.tabBar.dataProvider = localProvider;
			}
			//this.tabBar.selectedIndex = 0;
			this.tabBar.move(prevBut.width,0);
			this.tabBar.autoSizeTabsToTextWidth = true;

			this.tabBar.addEventListener( Event.CHANGE, tabBarChangeHandler );
			this.tabBar.addEventListener(Event.RENDER, tabBarRendered);
			
			if (needToMove > 0)
			{
				this.tabBar.scrollRect = new Rectangle(0, 0, needToMove - nextBut.width - prevBut.width, 200);
				nextBut.move(needToMove-nextBut.width,0);			
			}
			addChild(this.tabBar);
		}

		override public function set width(value:Number):void
		{
			if (this.tabBar != null)
			{
				tabBar.scrollRect = new Rectangle(0, 0, value - nextBut.width - prevBut.width - (padding*2), 200);
				tabBar.width =  value - nextBut.width - prevBut.width - (padding*2);
				tabBar.move(prevBut.width ,0);
				nextBut.move(value-nextBut.width,0);			
			}
			else
			{
				needToMove = value;
			}
		}	
		
		private function tabBarRendered( event:Event ):void
		{
			if(tabBar.scrollRect)
			{
				
				if (this.tabBar.scrollRect.width >= this.tabBar.width)
				{
					nextBut.visible = false;
					prevBut.visible = false;
				}
				else
				{
					nextBut.visible = true;
					prevBut.visible = true;				
				}
			}
		}
		
		private function tabBarChangeHandler( event:Event ):void
		{
			var tb:TabBar = ( event.currentTarget as TabBar );
			var index:int = tb.selectedIndex;
			var arr:Array = new Array(1);
			arr[0] = tb.dataProvider.getItemAt(index);
			(this.parent as tabBarCodePlugin).selectedDataProvider = new DataProvider(arr);
		}
		
		public function initialize(provider:DataProvider):void
		{
			localProvider = provider;
			if (this.tabBar != null)
			{
				this.tabBar.dataProvider = provider;
			}
		}
			
		public function setSkin(skinName:String, setSkinSize:Boolean=false):void
		{
		}
	}
}