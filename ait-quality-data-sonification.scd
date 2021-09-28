// Source AQI (Air Quality Index):
//  - https://en.wikipedia.org/wiki/Air_quality_index
//  - https://airindex.eea.europa.eu

// Todo:
// How To check if a Synth is running?

// - GUI
//   - Frequency Fader
//   - Volume Knob
//   - AQI Testing Range

// - Functions
//   - Exit Codes

// Syth Defs
(
// SynthDefs
// - Sine Tone for Reference
SynthDef( \SimpleSine, { arg freq, amp;
	Out.ar( [0,1], SinOsc.ar( freq, 0, amp ) );
}).add;

SynthDef( \SimpleSaw, { arg freq, amp;
	Out.ar( [0,1], Saw.ar( freq, amp ) );
}).add;

)

//////////////////////////////////////////////////////////////////////////////////
// Version 0.3

(
//------------------------
//- Init Global Vaiables -
//------------------------

// Values
var freq; // Global Fundamental Frequency, as given from the GUI
var amp;  // Global Amplitude, as given from GUI
var bpm;  // Global BPM, as given from GUI

// Settings
var aqi_scale = [3/2, 9/4, 27/8, 81/16, 243/32, 729/64]; // Mapping Scale for AQI Class to Frequency, as given from the GUI
var aqi_band = [0, 20, 40, 50, 100, 150, 1200]; // Make Selectable in GUI?
var aqi_testing = 0; // Testing AQI, as given from GUI

// Data
var data = nil;

// Synths
var synth_reference, synth_reference_running = false; // reference Synths
var synth_testing, synth_testing_running = false; // testing Synths
var synth_sonification;

// Tasks
var task_sonification;

// GUI Elements
var slider_aqi_testing, box_aqi_testing; // Handler for AQI Testing Box and Slider
var text_file, box_colum; // Handler for File Text Field and Colum Selector
//var box_bpm; // Handler for BPM Setting
//var numberbox_amp, numberbox_aqi;
//var btn_reference, btn_testing;
//var slider_aqi;



//------------------
//- Init Functions -
//------------------

// Start AQI Synths
var start_aqi_synth = {
	Array.fill(6, {arg i;
		//var fr = freq * aqi_scale[i];
		Synth( \SimpleSine, [\freq, 0, \amp, 0] );
	});
};

// Set AQI Synth AMP
var map_aqi_to_amp = { arg aqi, synth;
	// Loop trough all Synth
	6.do({ arg i;
		var ampli;
		if( aqi < aqi_band[i+1] , {
			if( aqi > aqi_band[i], {
				// If AQI in Band - Calculate Amplitude
				ampli = amp * ( (aqi-aqi_band[i])/(aqi_band[i+1]-aqi_band[i]) );
			}, {
				// If AQI lower than Band, set Amplitude to 0
				ampli = 0;
			});
		}, {
			// If Aqi higher than Band, set Amplitude to Global Value
			ampli = amp;
		});
		synth[i].set(\amp, ampli);
	});
};

// Set AQI Synth Freq
var map_scale_to_freq = { arg synth;
	6.do({ arg i;
		var fr = freq * aqi_scale[i];
		synth[i].set(\freq, fr);
	});
};

// Start Reference Synth
var start_reference_synth = {
	"test".postln;
	if( synth_reference_running.not , {
		"Start Reference Snyth with frequency: ".post; freq.post; "Hz and Amplitude: ".post; amp.postln;
		synth_reference = Synth( \SimpleSine, [\freq, freq, \amp, amp] );
		synth_reference_running = true;
	}, {
		"Reference Synth allready running."
	});
};

// Stop Reference Synth
var stop_reference_synth = {
	if( synth_reference_running , {
		"Stop Reference Synth".postln;
		synth_reference.free;
		synth_reference_running = false;
	}, {
		"Reference Synth not running."
	});
};

//--------------
//- Init Tasks -
//--------------
var play_set = Task({
	var t_play = 60/bpm;
	data.do({ arg value, counter;
		"PM2.5: ".post;
		value.postln;
		map_aqi_to_amp.value(value, synth_sonification);
		t_play.wait;
	});
	synth_sonification.do({ arg synth;
		synth.free;
	});
});

//-------------------------
//- Init Action Functions -
//-------------------------

// Start and Stop Reference Synth
var reference_btn_action = { arg states;
	if(states.value == 1, { start_reference_synth.value },{ stop_reference_synth.value });
};

// Start and Stop Testing Synth
var testing_btn_action = {arg states;
	if(states.value == 1, { // Press Play - Start Testing Synth
		"Start Testing Snyths with frequency: ".post; freq.post; "Hz and Amplitude: ".post; amp.postln;
		synth_testing = start_aqi_synth.value;
		map_aqi_to_amp.value(aqi_testing, synth_testing);
		map_scale_to_freq.value(synth_testing);
		synth_testing_running = true;
	},{ // Press Stop - Stop Referece Synth
		"Stop Testing Synth".postln;
		synth_testing.do({ arg synth;
			synth.free;
		});
		synth_testing_running = false;
	});
};

// Set Reference Frequency on: Reference Synth, Testing Synth
var reference_set_freq = {arg num;
	freq = num.value; // Set Global Frequency
	"Reference Freq set to: ".post; freq.postln;
	// Check if Reference Synth is Running
	if(  synth_reference_running ,
		{ synth_reference.set(\freq, freq) }
	);
	if( synth_testing_running ,
		{ map_scale_to_freq.value(synth_testing) }
	);
};

// Set Reference Amplitude on: Reference Synth, Testing Synth
var reference_set_amp = {arg num;
	amp = num.value; // Set Global Amplitude
	"Reference Amplitude set to: ".post; amp.postln;
	// Check if Reference Synth is Running
	if( synth_reference_running ,
		{ synth_reference.set(\amp, amp) }
	);
	if( synth_testing_running ,
		{ map_aqi_to_amp.value(aqi_testing, synth_testing) }
	);
};

// Set Mapping Scale
var mapping_set_scale = {arg select;
	"Selectet Scale: ".post; select.value.postln;
	aqi_scale = switch( select.value,
		0, { [3/2, 9/4, 27/8, 81/16, 243/32, 729/64] },
		1, { [3/2, 9/8, 27/16, 81/64, 243/128, 729/512] },
		2, { [2, 3, 4, 5, 6, 7] },
		3, { [3/2, 81/64, 243/128, 4/3, 243/128, 9/8] },
	);
	if( synth_testing_running ,
		{ map_scale_to_freq.value(synth_testing) };
	);
};

// Set Testing AQI Value
var testing_set_aqi_slider = {arg num;
	aqi_testing = num.value*250;
	"Testing AQI set to: ".post; aqi_testing.postln;
	if( synth_testing_running ,
		{ map_aqi_to_amp.value(aqi_testing, synth_testing) }
	);
	box_aqi_testing.value = aqi_testing;
};
var testing_set_aqi_number = {arg num;
	slider_aqi_testing.valueAction = num.value/250;
};

// Open File Dialog
var open_file_dialog = {arg state;
	FileDialog({ |paths|
		postln("Selected path:" + paths[0]);
		text_file.value = paths[0];
	}, {
		postln("Dialog was cancelled. Try again.");
    });
};

// Load Data
var load_data = {arg state;
	var raw_data;
	// Read Data
	raw_data = CSVFileReader.read( text_file.value, true );
	// Remove Header
	"Selected Colum: ".post;
	raw_data[0][box_colum.value].postln;
	raw_data.removeAt(0);
	// Store requiered data
	data = Array.newClear;
	raw_data.do( {arg line, i;
		data = data.add(line[box_colum.value].asFloat);
	});
	"data loaded".postln;
};

// Start/Stop Sonification
var start_sonification = {arg state;
	if( state.value == 1 , {
		start_reference_synth.value;
		// kill testing synth if running
		if( synth_testing_running, {
			"Stop Testing Synth".postln;
			synth_testing.do({ arg synth;
				synth.free;
			});
		});

		// Start AQI Synths
		synth_sonification = start_aqi_synth.value();
		map_scale_to_freq.value(synth_sonification);

		// Run Task
		play_set.play;
	}, {
		stop_reference_synth.value;

		// Stop Routine
		play_set.stop;
		play_set.reset;

		// Stop AQI Synths
		synth_sonification.do({ arg synth;
			synth.free;
		});
	});
};



//-------------
//- Setup GUI -
//-------------

// set Fonts
var h1 = Font.new( size: 18, bold: true);

// Init Window
var win = Window.new( "Air Quality Data Sonification" )
.background_( Color.black)
.front
.layout_(
	HLayout(
		GridLayout.rows(
			[[StaticText().string_("Reference Tone").stringColor_(Color.green).font_(h1), columns:3]],
			[
				HLayout(
					// Set Reference Frequency
					VLayout(
						StaticText().string_("Frequency").stringColor_(Color.green).align_(\center),
						NumberBox()
						.action_( reference_set_freq )
						.valueAction_(440)
						.clipLo_(60).clipHi_(10000)
						.align_(\right)
						.stringColor_(Color.green)
						.normalColor_(Color.green)
						.typingColor_(Color.red)
						.background_( Color.black )
					),
					// Set Reference Amplitude
					VLayout(
						StaticText().string_("Volume").stringColor_(Color.green).align_(\center),
						NumberBox()
						.action_( reference_set_amp )
						.valueAction_(0.5)
						.clipLo_(0).clipHi_(1)
						.align_(\right)
						.stringColor_(Color.green)
						.normalColor_(Color.green)
						.typingColor_(Color.red)
						.background_( Color.black )
					)
				)
			],
			[
				// Start Stop Button for Reference Synth
				Button()
				.states_(
					[["Start Reference", Color.green, Color.black], ["Stop Reference", Color.red, Color.black]]
				)
				.action_( reference_btn_action )
				.focusColor_( Color.green )
			],
			[StaticText().string_("Select Mapping Scale").stringColor_(Color.green).font_(h1)],
			[
				// List of all selectable Mapping Scales
				ListView()
				.items_([
					"Fifth Shift",
					"Fifth Shift - One Oktave",
					"Overtones",
					"Dur Tonic",
				])
				.valueAction_(0)
				.colors_(Color.black)
				.stringColor_(Color.green)
				.hiliteColor_(Color.magenta)
				.background_(Color.black)
				.selectionMode_(\single)
				.action_( mapping_set_scale )
			],
			[StaticText().string_("Setup Testing").stringColor_(Color.green).font_(h1)],
			[
				VLayout(
					StaticText().string_("Set AQI Test Value").stringColor_(Color.green).align_(\center),
					// Slider to controll Test AQI Value
					HLayout(
						slider_aqi_testing = Slider()
						.valueAction_(0)
						.orientation_(\horizontal)
						.knobColor_(Color.red)
						.action_( testing_set_aqi_slider ),
						box_aqi_testing = NumberBox()
						.action_( testing_set_aqi_number )
						.value_(0)
						.clipLo_(0).clipHi_(1200)
						.align_(\right)
						.stringColor_(Color.green)
						.normalColor_(Color.green)
						.typingColor_(Color.red)
						.background_( Color.black )
					)
				)
			],
			[
				// Start Stop Button for Testing
				Button()
				.states_(
					[["Start Testing", Color.green, Color.black], ["Stop Testing", Color.red, Color.black]]
				)
				.action_( testing_btn_action )
				.focusColor_( Color.green )
			],
			[StaticText().string_("Load Data File").stringColor_(Color.green).font_(h1)],
			[
				Button()
				.states_(
					[["Open File", Color.green, Color.black]]
				)
				.action_( open_file_dialog )
				.focusColor_( Color.green ),
				text_file = TextField()
				.string_("Set File Path")
				.align_(\right)
				.stringColor_( Color.green )
				.background_( Color.black )
			],
			[
				StaticText().string_("Select Data Column").stringColor_(Color.green),
				box_colum = NumberBox()
				.action_( )
				.value_(0)
				.align_(\right)
				.stringColor_(Color.green)
				.normalColor_(Color.green)
				.typingColor_(Color.red)
				.background_( Color.black )
			],
			[
				Button()
				.states_(
					[["Load Data", Color.green, Color.black]]
				)
				.action_( load_data )
				.focusColor_( Color.green )
			],
			[StaticText().string_("Playback Settings").stringColor_(Color.green).font_(h1)],
			[
				StaticText().string_("Set BPM (Data Points per Minute)").stringColor_(Color.green),
				NumberBox()
				.action_( { arg num; bpm = num.value } )
				.valueAction_(120)
				.align_(\right)
				.stringColor_(Color.green)
				.normalColor_(Color.green)
				.typingColor_(Color.red)
				.background_( Color.black )
			],
			[
				Button()
				.states_(
					[["Start", Color.green, Color.black], ["Stop", Color.green, Color.black]]
				)
				.action_( start_sonification )
				.focusColor_( Color.green )
			]
		)
	)
);

)

// Testing Area!