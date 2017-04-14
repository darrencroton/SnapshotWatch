using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Math as Math;
using Toybox.Time as Time;
using Toybox.Time.Gregorian as Calendar;
using Toybox.WatchUi as Ui;
using Toybox.Application as App;
using Toybox.ActivityMonitor as ActMon;
using Toybox.SensorHistory as Sensor;
using Toybox.Activity as Activity;

enum
{
    LAT,
    LON
}


class SnapshotWatchView extends Ui.WatchFace {
	
	var usePreferences = true;
	var showHeartRate = true;
	var showDigitalTime = false;
	var digitalTimeOffset = 0;

	var showSeconds = true;
	var background_color = Gfx.COLOR_BLACK;
	var width_screen, height_screen;
	var hashMarksArray = new [60];


    //! Load your resources here
    function onLayout(dc) {
        	
    	//get screen dimensions
		width_screen = dc.getWidth();
		height_screen = dc.getHeight();

		//get hash marks position
		for(var i = 0; i < 60; i+=1)
		{
			hashMarksArray[i] = new [2];
			hashMarksArray[i][0] = (i / 60.0) * Math.PI * 2;

			if(i != 0 && i != 15 && i != 30 && i != 45)
			{
				hashMarksArray[i][1] = -85;
    		}
    		else
			{
				hashMarksArray[i][1] = -67;
	    	}
		}
		
        setLayout(Rez.Layouts.WatchFace(dc));
    }


    //! Restore the state of the app and prepare the view to be shown
    function onShow() {
    }

    //! Update the view
    function onUpdate(dc) {

		if (usePreferences) {
			showHeartRate = Application.getApp().getProperty("showHeartRate");
			showDigitalTime = Application.getApp().getProperty("showDigitalTime");
			digitalTimeOffset = Application.getApp().getProperty("digitalTimeOffset");
		}

		if (showDigitalTime)
		{
			if (digitalTimeOffset != null && digitalTimeOffset <= 24 && digitalTimeOffset >= -24) {
				digitalTimeOffset = digitalTimeOffset.toNumber();
			} 
			else
			{
				showDigitalTime = false;
				digitalTimeOffset = 0;
			}
    	}
    	
        var clockTime = Sys.getClockTime();

        // Clear screen
        dc.setColor(background_color, Gfx.COLOR_WHITE);
//		dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_DK_GRAY);
        dc.fillRectangle(0,0, width_screen, height_screen);

		var heartNow = 0;
		var heartMin = 0;
		var heartMax = 0;

		if (showHeartRate)
		{
	 		// Plot heart rate graph
			var sample = Sensor.getHeartRateHistory( {:order=>Sensor.ORDER_NEWEST_FIRST} );
		    if (sample != null)
		    {
		    	if (sample.getMin() != null)
		    	{ heartMin = sample.getMin(); }
		    	
		    	if (sample.getMax() != null)
		    	{ heartMax = sample.getMax(); }
		    	
		    	var heart = sample.next();
				if (heart.data != null)
				{ heartNow = heart.data; }
	
				dc.setColor(Gfx.COLOR_DK_GREEN, Gfx.COLOR_TRANSPARENT);
	
				var maxSecs = 14355;//14400; //4 hours
				var totHeight = 44;
				var totWidth = 165;
				var binPixels = 1;
	
				var totBins = Math.ceil(totWidth / binPixels).toNumber();
				var binWidthSecs = Math.floor(binPixels * maxSecs / totWidth).toNumber();	
	
				var heartSecs;
				var heartValue = 0;
				var secsBin = 0;
				var lastHeartSecs = sample.getNewestSampleTime().value();
				var heartBinMax;
				var heartBinMin;
	
				var finished = false;
				
				for (var i = 0; i < totBins; ++i) {
	
					heartBinMax = 0;
					heartBinMin = 0;
				
					if (!finished)
					{
						//deal with carryover values
						if (secsBin > 0 && heartValue != null)
						{
							heartBinMax = heartValue;
							heartBinMin = heartValue;
						}
	
						//deal with new values in this bin
						while (!finished && secsBin < binWidthSecs)
						{
							heart = sample.next();
							if (heart != null)
							{
								heartValue = heart.data;
								if (heartValue != null)
								{
									if (heartBinMax == 0)
									{
										heartBinMax = heartValue;
										heartBinMin = heartValue;
									}
									else
									{
										if (heartValue > heartBinMax)
										{ heartBinMax = heartValue; }
										
										if (heartValue < heartBinMin)
										{ heartBinMin = heartValue; }
									}
								}
								
								// keep track of time in this bin
								heartSecs = lastHeartSecs - heart.when.value();
								lastHeartSecs = heart.when.value();
								secsBin += heartSecs;
	
//								Sys.println(i + ":   " + heartValue + " " + heartSecs + " " + secsBin + " " + heartBinMin + " " + heartBinMax);
							}
							else
							{
								finished = true;
							}
							
						} // while secsBin < binWidthSecs
	
						if (secsBin >= binWidthSecs)
						{ secsBin -= binWidthSecs; }
	
						// only plot bar if we have valid values
						if (heartBinMax > 0 && heartBinMax >= heartBinMin)
						{
							var height = ((heartBinMax+heartBinMin)/2-heartMin*0.9) / (heartMax-heartMin*0.9) * totHeight;
							var xVal = (width_screen-totWidth)/2 + totWidth - i*binPixels -2;
							var yVal = height_screen/2+28 + totHeight - height;
						
							dc.fillRectangle(xVal, yVal, binPixels, height);
							
//							Sys.println(i + ": " + binWidthSecs + " " + secsBin + " " + heartBinMin + " " + heartBinMax);
						}				
						
					} // if !finished
					
				} // loop over all bins
				
			} // if sample != null

		}
 
        // First draw hash marks the analogue time hands
		drawHashMarks(dc);
		drawHands(dc, clockTime.hour, clockTime.min, clockTime.sec);

		if (showHeartRate)
		{
			// Now show HR information (calculated above)
			dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
			
			if (heartNow == 0)
	        { dc.drawText(width_screen/2, height_screen/2 + 20, Gfx.FONT_SMALL, "-- bpm", Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER); }
			else
	        { dc.drawText(width_screen/2, height_screen/2 + 20, Gfx.FONT_SMALL, Lang.format("$1$ bpm", [heartNow]), Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER); }
			
			var heartMinMaxString;
	        if (heartMin == 0 || heartMax == 0)
	        { heartMinMaxString = "-- / -- bpm"; }
	        else
	        { heartMinMaxString = Lang.format("$1$ / $2$ bpm", [heartMin, heartMax]); }
	        dc.drawText(width_screen/2, height_screen - 19, Gfx.FONT_SMALL, heartMinMaxString, Graphics.TEXT_JUSTIFY_CENTER);

		}
		
        // Date
		dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
		drawDate(dc);
		
        // Digital time
        if (showDigitalTime)
        {
			dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
			drawDigitalTime(dc, clockTime);
		}

 		// BT, alarm, notification, and do not disturb icons
		if (Sys.getDeviceSettings().phoneConnected) 
		{
			dc.drawBitmap(39, 6, Ui.loadResource(Rez.Drawables.BluetoothIcon));
		}
 		
		if (Sys.getDeviceSettings().alarmCount > 0) 
		{
			dc.drawBitmap(25, 23, Ui.loadResource(Rez.Drawables.AlarmIcon));
		}
 		
		if (Sys.getDeviceSettings().doNotDisturb) 
		{
			dc.drawBitmap(10, 49, Ui.loadResource(Rez.Drawables.MuteIcon));
		}

		if (Sys.getDeviceSettings().notificationCount > 0) 
		{
			var offset = 0;
			if (Sys.getDeviceSettings().notificationCount >= 10)
			{
				offset = 6;
			}
			
        	dc.drawText(width_screen/2+16+offset, 7, Gfx.FONT_SMALL, Sys.getDeviceSettings().notificationCount, Graphics.TEXT_JUSTIFY_RIGHT|Graphics.TEXT_JUSTIFY_VCENTER);
			dc.drawBitmap(width_screen/2+18+offset, 2, Ui.loadResource(Rez.Drawables.NotificationIcon));
		}

 		// Battery
		var systemStats = Sys.getSystemStats();
        var battery = systemStats.battery;
        
        var offset = 0;
        if (battery == 100)
        { offset = 6; }
        
        dc.drawText(width_screen/2-33-offset, 7, Gfx.FONT_SMALL, Lang.format("$1$%", [battery.format("%2d")]), Graphics.TEXT_JUSTIFY_LEFT|Graphics.TEXT_JUSTIFY_VCENTER);

		// Steps
        var stepsInfo = ActMon.getInfo();
        var steps = stepsInfo.steps;        
        var goal = stepsInfo.stepGoal;        
        dc.drawText(width_screen-4, height_screen/2 - 14, Gfx.FONT_SMALL, steps, Graphics.TEXT_JUSTIFY_RIGHT|Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(width_screen-4, height_screen/2 + 11, Gfx.FONT_SMALL, goal, Graphics.TEXT_JUSTIFY_RIGHT|Graphics.TEXT_JUSTIFY_VCENTER);

		// Sunrise & sunset
		dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
		drawSunriseSunset(dc);

    }


    //! The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() {
		showSeconds = true;
    }


    //! Terminate any active timers and prepare for slow updates.
    function onEnterSleep() {
		showSeconds = false;
    	requestUpdate();
    }


    //! Draw the watch hand
    function drawHand(dc, angle, whichHand, width, handColour)
    {
		dc.setColor(handColour, Gfx.COLOR_TRANSPARENT);		

    	var length, r1, r2, r3, r4, deflect1, deflect2;

        var centerX = width_screen/2;
        var centerY = height_screen/2;
        
        if (whichHand == 0)  //hour hand
        {        
        	length = 0.6*centerX;
	        r1 = 0.0*length;
	        r2 = 0.39*length;
	        r3 = 0.49*length;
	        r4 = 1.1*length;
	        deflect1 = 0.10*width;
	        deflect2 = 0.08*width;
        }
        else //minute hand
        {
        	length = 1.0*centerX;
	        r1 = 0.0*length;
	        r2 = 0.37*length;
	        r3 = 0.47*length;
	        r4 = 1.2*length;
	        deflect1 = 0.10*width;
	        deflect2 = 0.08*width;
        }

		var coords = [
			[centerX + r1 * Math.sin(angle)          , centerY - r1 * Math.cos(angle)],						
			[centerX + r2 * Math.sin(angle+deflect1) , centerY - r2 * Math.cos(angle+deflect1)],
			[centerX + r3 * Math.sin(angle+deflect2) , centerY - r3 * Math.cos(angle+deflect2)],
			[centerX + r4 * Math.sin(angle)          , centerY - r4 * Math.cos(angle)],
			[centerX + r3 * Math.sin(angle-deflect2) , centerY - r3 * Math.cos(angle-deflect2)],
			[centerX + r2 * Math.sin(angle-deflect1) , centerY - r2 * Math.cos(angle-deflect1)],						
			[centerX + r1 * Math.sin(angle)          , centerY - r1 * Math.cos(angle)]
		];	

		dc.fillPolygon(coords);
		
    }


	function drawHands(dc, clock_hour, clock_min, clock_sec)
	{
        var hour, min, sec;

		// Draw the hour. Convert it to minutes and compute the angle.
        hour = ( ( ( clock_hour % 12 ) * 60 ) + clock_min ); // hour = 2*60.0;
        hour = hour / (12 * 60.0) * Math.PI * 2;
        drawHand(dc, hour, 0, 2.0, Gfx.COLOR_DK_BLUE);
        drawHand(dc, hour, 0, 1.6, Gfx.COLOR_LT_GRAY);

        // Draw the minute
        min = ( clock_min / 60.0); // min = 40/60.0;
        min = min * Math.PI * 2;
        drawHand(dc, min, 1, 1.2, Gfx.COLOR_DK_BLUE);
        drawHand(dc, min, 1, 1.0, Gfx.COLOR_LT_GRAY);

        // Draw the seconds (use hash graphic here)
		if(showSeconds){
			sec = ( clock_sec / 60.0) *  Math.PI * 2;
        	drawHash(dc, sec, width_screen/2, 4, 25, Gfx.COLOR_DK_BLUE);
        	drawHash(dc, sec, width_screen/2, 2, 25, Gfx.COLOR_LT_GRAY);
        }

        // Draw the inner circle
        dc.setColor(Gfx.COLOR_DK_GRAY, background_color);
        dc.fillCircle(width_screen/2, height_screen/2, 6);
        dc.setColor(background_color,background_color);
        dc.drawCircle(width_screen/2, height_screen/2, 6);
        dc.fillCircle(width_screen/2, height_screen/2, 2);
	}
	

    function drawHash(dc, angle, length, width, overheadLine, handColour)
    {
		dc.setColor(handColour, Gfx.COLOR_TRANSPARENT);		

        var centerX = width_screen/2;
        var centerY = height_screen/2;

        var result = new [4];
        var cos = Math.cos(angle);
        var sin = Math.sin(angle);
        
        var coords = [ 
        	[-(width/2), 0 + overheadLine],
        	[-(width/2), -length],
        	[width/2, -length],
        	[width/2, 0 + overheadLine]
    	];

        for (var i = 0; i < 4; i += 1)
        {
            var x = (coords[i][0] * cos) - (coords[i][1] * sin);
            var y = (coords[i][0] * sin) + (coords[i][1] * cos);
            result[i] = [ centerX + x, centerY + y];
        }

        dc.fillPolygon(result);
		
    }


    //! Draw the hash mark symbols
    function drawHashMarks(dc)
    {

		for(var i = 0; i < 60; i += 5)
		{
			if(i != 30)
			{
				if(i != 0 && i != 15 &&  i != 45)
				{
	    			drawHash(dc, hashMarksArray[i][0], 110, 3, hashMarksArray[i][1], Gfx.COLOR_WHITE);
	    		} else {
	    			drawHash(dc, hashMarksArray[i][0], 110, 5, hashMarksArray[i][1], Gfx.COLOR_WHITE);
	    		}
	    	}
	    	
	    	if(!showHeartRate && i == 30)
	    	{
				drawHash(dc, hashMarksArray[i][0], 110, 5, hashMarksArray[i][1], Gfx.COLOR_WHITE);
	    	}
		}
    }


	function drawDate(dc)
	{
        var info = Calendar.info(Time.now(), Time.FORMAT_LONG);
        var dateStr = Lang.format("$1$ $2$ $3$", [info.day_of_week, info.month, info.day]);

		if (showDigitalTime)
		{
    		dc.drawText(width_screen/2, height_screen/2 - 60, Gfx.FONT_MEDIUM, dateStr, Gfx.TEXT_JUSTIFY_CENTER);
    	}
    	else
    	{
    		dc.drawText(width_screen/2, height_screen/2 - 55, Gfx.FONT_MEDIUM, dateStr, Gfx.TEXT_JUSTIFY_CENTER);
    	}
    }


    function drawDigitalTime(dc, clockTime)
    {
    
    	var offsetHour = clockTime.hour + digitalTimeOffset;

    	if (offsetHour > 23)
    	{
    		offsetHour -= 24;
    	} 
    	else if (offsetHour < 0)
    	{
    		offsetHour += 24;
    	}
    	
		var ampm = "am";
    	if (offsetHour >= 12)
    	{
    		ampm = "pm";
    	}
    	
        var timeString = Lang.format("$1$:$2$$3$", [to12hourFormat(offsetHour), clockTime.min.format("%02d"), ampm]);
        dc.drawText(width_screen/2, height_screen/2 - 30, Gfx.FONT_SMALL, timeString, Gfx.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);

    }


    function drawSunriseSunset(dc)
    {
		var sc = new SunCalc();
		var lat;
		var lon;
		
		var loc = Activity.getActivityInfo().currentLocation;
		if (loc == null)
		{
			lat = App.getApp().getProperty(LAT);
			lon = App.getApp().getProperty(LON);
		} 
		else
		{
			lat = loc.toDegrees()[0] * Math.PI / 180.0;
			App.getApp().setProperty(LAT, lat);
			lon = loc.toDegrees()[1] * Math.PI / 180.0;
			App.getApp().setProperty(LON, lon);
		}

//		lat = -37.81400 * Math.PI / 180.0;
//		lon = 144.96332 * Math.PI / 180.0;

		if(lat != null && lon != null)
		{
			var ampm;
			var timeString;
			
			var now = new Time.Moment(Time.now().value());			
			var sunrise_moment = sc.calculate(now, lat.toDouble(), lon.toDouble(), SUNRISE);
			var sunset_moment = sc.calculate(now, lat.toDouble(), lon.toDouble(), SUNSET);

			var timeInfoSunrise = Calendar.info(sunrise_moment, Time.FORMAT_SHORT);
			var timeInfoSunset = Calendar.info(sunset_moment, Time.FORMAT_SHORT);

			ampm = "a";
    		if (timeInfoSunrise.hour >= 12)
    		{
    			ampm = "p";
    		}
    	
        	timeString = Lang.format("$1$:$2$$3$", [to12hourFormat(timeInfoSunrise.hour), timeInfoSunrise.min.format("%02d"), ampm]);
        	dc.drawText(3, height_screen/2 - 14, Gfx.FONT_SMALL, timeString, Gfx.TEXT_JUSTIFY_LEFT|Graphics.TEXT_JUSTIFY_VCENTER);

			ampm = "a";
    		if (timeInfoSunset.hour >= 12)
    		{
    			ampm = "p";
    		}
    	
        	timeString = Lang.format("$1$:$2$$3$", [to12hourFormat(timeInfoSunset.hour), timeInfoSunset.min.format("%02d"), ampm]);
        	dc.drawText(3, height_screen/2 + 11, Gfx.FONT_SMALL, timeString, Gfx.TEXT_JUSTIFY_LEFT|Graphics.TEXT_JUSTIFY_VCENTER);

		}

	} 


	function to12hourFormat(hour) 
	{
		var hour12 = hour % 12;
		if (hour12 == 0) {
			hour12 = 12;
		}
		
		return hour12;
	}
	
}

