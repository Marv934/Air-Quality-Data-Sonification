// Source AQI (Air Quality Index):
//  - https://en.wikipedia.org/wiki/Air_quality_index
//  - https://airindex.eea.europa.eu

//----------
//- Server -
//----------

(
SynthDef( \Reference, {arg freq = 440, amp = 0.5;
	Out.ar( [0, 1] , SinOsc.ar(freq, 0, amp, 0));
}).add;

SynthDef( \AQI, {arg freq = 440, freqmul = 1, amp = 0.5, ampmul = 1;
	Out.ar( [0, 1] , SinOsc.ar(freq * freqmul, 0, amp * ampmul, 0));
}).add;
)

(
//-------
//- GUI -
//-------

//---------------
//- Init Busses -
//---------------
var fundfreq = Bus.control(s, 1);
var fundamp = Bus.control(s, 1);

//---------------------------------
//- Init GUI and Setup Appearance -
//---------------------------------

// set Fonts
var h1 = Font.new( size: 18, bold: true );

//-------------------------------
//- Start Audio setting section -
//--------------------------------
// Fundamental Frequency Settings
var spec_fundfreq = ControlSpec( 60, 10000, \exp, 1 );

var win_fundfreq_box = NumberBox().align_( \right )
.action_({ arg num;
	fundfreq.value = num.value;
} )
.valueAction_( 440 ).clipLo_( 60 ).clipHi_( 10000 );

var win_fundfreq_slider = Slider()
.action_( {
	win_fundfreq_box.valueAction_( spec_fundfreq.map( win_fundfreq_slider.value ) )
} )
.value_( spec_fundfreq.unmap( 440 ) );

// Fundamental Amplitude Settings
var win_fundamp_box = NumberBox().align_( \right )
.action_({ arg num;
	fundamp.value = num.value;
} )
.valueAction_( 0.5 ).clipLo_( 0 ).clipHi_( 1 );

var win_fundamp_slider = Slider()
.action_( {
	win_fundamp_box.valueAction_( win_fundamp_slider.value )
} )
.value_( 0.5 );

// Frequency Mappig Selection
var array_scale = [
	[3/2, 9/4, 27/8, 81/16, 243/32, 729/64],
	[3/2, 9/8, 27/16, 81/64, 243/128, 729/512],
	[2, 3, 4, 5, 6, 7],
	[3/2, 81/64, 243/128, 4/3, 243/128, 9/8]
];

var win_scale_select = ListView()
.valueAction_( 0 ).selectionMode_( \single )
.items_( [
	"Fifth Shift",
	"Fifth Shift - One Oktave",
	"Overtones",
	"Dur Tonic",
] );

// Partikel Breakpoint selection
var aqi_spec;

var array_breakpoints = [
	[0, 20, 40, 50, 100, 150, 1200], // PM 10
	[0, 10, 20, 25, 50, 75, 800] //PM 2.5
];

var win_breakpoints_select = ListView()
.action_( { arg sel;
	aqi_spec = Array.fill( array_breakpoints[ sel.value].size - 1, {arg i;
		ControlSpec(
			array_breakpoints[sel.value][i],
			array_breakpoints[sel.value][i+1],
			\lin, 1
		);
	} );
})
.items_( [
	"PM 10",
	"PM 2.5",
] )
.selectionMode_( \single )
.valueAction_( 0 );

//-----------------------
// Audio Setting Layout
var win_settings_audio = GridLayout.columns(
	[
		StaticText().string_("Fundamental Frequency").align_(\center),
		win_fundfreq_slider,
		win_fundfreq_box
	], [
		StaticText().string_("Fundamental Amplitude").align_(\center),
		win_fundamp_slider,
		win_fundamp_box
	], [
		StaticText().string_("Select Scale"),
		win_scale_select
		// Maybe selection of lin/log/const Amplitude Mapping
	], [
		StaticText().string_("Select Breakpoints"),
		win_breakpoints_select
	]
);
//----------------------------
// End Audio setting section -
//----------------------------

//------------------------
// Start Testing section -
//------------------------
// Set data value slider
var test_ampmul = Array.fill( array_scale[ win_scale_select.value ].size, {arg i;
	Bus.control(s, 1).value_(0);
} );

var win_testdata_box = NumberBox().align_( \right )
.action_( { arg num;
	aqi_spec.do( { arg spec, i;
		test_ampmul[i].value = ( spec.unmap( num.value ) );
	} );
} )
.valueAction_( 0 );

var win_testdata_slider = Slider().orientation_( \horizontal )
.action_( {
	var spec_testdata = ControlSpec(
		array_breakpoints[win_breakpoints_select.value][0],
		array_breakpoints[win_breakpoints_select.value][6],
		\lin, 1
	);
	win_testdata_box.valueAction_( spec_testdata.map( win_testdata_slider.value ) )
} )
.value_( 0 );

// Referene Tone Start/Stop Button
var reference;

var win_reference_btn = Button()
.action_( { arg state;
	if( state.value == 1, {
		reference = Synth( \Reference );
		reference.map(\freq, fundfreq.index);
		reference.map(\amp, fundamp.index);
	}, {
		reference.free;
		reference = nil;
	});
} )
.states_( [["Start Reference", Color.black, Color.green], ["Stop Reference", Color.black, Color.red]] );

// Referene Tone Start/Stop Button
var test;

var win_test_btn = Button()
.action_( { arg state;
	if( state.value == 1, {
		test = Array.fill( array_scale[ win_scale_select.value ].size, {arg i;
			Synth( \AQI, [\freqmul, array_scale[ win_scale_select.value ][i] ] )
			.map(\freq, fundfreq.index, \amp, fundamp.index, \ampmul, test_ampmul[i].index);
		} );
		aqi_spec.do( { arg spec, i;
			test_ampmul[i].value = ( spec.unmap( win_testdata_box.value ) );
		} );
	}, {
		test.do( { arg synth;
			synth.free;
		});
		test = nil;
	} );
} )
.states_( [["Start Sonification", Color.black, Color.green], ["Stop Sonification", Color.black, Color.red]] );

//----------------
// Testing Layout
var win_testing = GridLayout.rows(
	[
		StaticText().string_("Try it out"),
		win_reference_btn,
		win_test_btn
	], [
		StaticText().string_("Set Data Value"),
		win_testdata_slider,
		win_testdata_box
	]
);

//----------------------
// End Testing section -
//----------------------

//------------------------------
//- Start Data Loading section -
//------------------------------
// File Path, Select File
var win_file_text = TextField().string_("File Path").align_(\right);

var win_file_btn = Button().states_( [["Select File"]] )
.action_({arg state;
	FileDialog({ |paths|
		win_file_text.value = paths[0];
	}, {
		postln("Dialog was cancelled. Try again.");
	});
});

// Select Data colum
var win_datacolum_box = NumberBox().action_( ).value_(0).align_(\right);

var win_datacolum_text = StaticText().string_("No Data Loaded");

// Load Data
var data;

var win_loaddata_btn = Button().states_( [["Load Data"]] )
.action_( {arg state;
	var raw_data;

	// Read Data
	raw_data = CSVFileReader.read( win_file_text.value, true );

	// Remove Header
	win_datacolum_text.string_(raw_data[0][win_datacolum_box.value]);
	raw_data.removeAt(0);

	// Store requiered data
	data = Array.newClear;
	raw_data.do( {arg line, i;
		data = data.add(line[win_datacolum_box.value].asFloat);
	});
} );

// Data Loading Layout
var win_loading = GridLayout.rows(
	[
		win_file_btn,
		[ win_file_text, columns:2 ]
	], [
		StaticText().string_("Select Air Quality Data Column"),
		win_datacolum_box,
		win_datacolum_text
	], [
		[ win_loaddata_btn, columns:3 ]
	]
);
//----------------------------
//- End Data Loading section -
//----------------------------

//--------------------------
//- Start Playback section -
//--------------------------
var sonify;
var bpm;
var sonify_ampmul = Array.fill( array_scale[ win_scale_select.value ].size, {arg i;
	Bus.control(s, 1).value_(0);
} );

// Set BPM
var win_bpm_box = NumberBox().align_(\right)
.action_( { arg num;
	bpm = num.value;
})
.valueAction_(120);

// Sonification Task
var task_sonify = Task({
	// Calculate waiting time
	var dt = 0.01; //60/bpm;

	// Loop trough data
	data.do({ arg value, counter;
		"AQI: ".post;
		value.postln;

		// Map AQI to ampmul
		aqi_spec.do( { arg spec, i;
			sonify_ampmul[i].value = ( spec.unmap( value ) );
		} );
		dt.wait;
	});

	// Stop Synth
	//sonify.do({ arg synth;
	//	synth.free;
	//});
});

// Play Button
var win_play_btn = Button().states_( [["Play"], ["Play", Color.black, Color.green]] )
.action_( { arg state;

	// Check if allready playing
	if( state.value == 1, { // Not Playing

		// Check if Reference Synth allready playing
		if( win_reference_btn.value == 0 , { // Not playing

			// Start Reference and Set Button
			reference = Synth( \Reference );
			reference.map(\freq, fundfreq.index);
			reference.map(\amp, fundamp.index);
			win_reference_btn.value_( 1 )
		});

		// Check if testing Synth is playing
		if( win_test_btn.value == 1 , { // Is playing

			// Stop testing synth and set button
			test.do({ arg synth;
				synth.free;
			});
			win_test_btn.value_( 0 );
			test = nil;
		});

		// Start Synth
		sonify = Array.fill( array_scale[ win_scale_select.value ].size, {arg i;
			Synth( \AQI, [\freqmul, array_scale[ win_scale_select.value ][i] ] )
			.map(\freq, fundfreq.index, \amp, fundamp.index, \ampmul, sonify_ampmul[i].index);
		} );

		// Start Data Loop
		task_sonify.play;
	}, { // Playing, do nothing
		state.value_( 1 );
	} );
});


// Pause Button
var win_pause_btn = Button().states_( [["Pause", Color.black, Color.yellow], ["Resume", Color.black, Color.green]] )
.action_( { arg state;

	// check if playing
	if( win_play_btn.value == 1, { // is playing
		if( state.value == 1, { // and running
			task_sonify.pause;

			// Stop Synth
			sonify.do({ arg synth;
				synth.free;
			});
			reference.free;

			win_reference_btn.value_(0);
		}, { // and paused
			// Check if Reference Synth allready playing
			if( win_reference_btn.value == 0 , { // Not playing

				// Start Reference and Set Button
				reference = Synth( \Reference );
				reference.map(\freq, fundfreq.index);
				reference.map(\amp, fundamp.index);
				win_reference_btn.value_( 1 )
			});

			// Check if testing Synth is playing
			if( win_test_btn.value == 1 , { // Is playing

				// Stop testing synth and set button
				test.do({ arg synth;
					synth.free;
				});
				win_test_btn.value_( 0 );
				test = nil;
			});

			// Start Synth
			sonify = Array.fill( array_scale[ win_scale_select.value ].size, {arg i;
				Synth( \AQI, [\freqmul, array_scale[ win_scale_select.value ][i] ] )
				.map(\freq, fundfreq.index, \amp, fundamp.index, \ampmul, sonify_ampmul[i].index);
			} );

			// Play Data Loop
			task_sonify.play;
		} );
	}, { // not playing
		state.value_( 0 );
	} );
});

// Stop Button
var win_stop_btn = Button().states_( [["Stop", Color.black, Color.red]] )
.action_( { arg state;

	// check if playing
	if( win_play_btn.value == 1, { // is playing
		if( win_pause_btn.value == 0, { // not paused
			task_sonify.stop;

			// Stop Synth
			sonify.do({ arg synth;
				synth.free;
			});
			reference.free;
		} );
		task_sonify.reset;

		win_play_btn.value_(0);
		win_pause_btn.value_(0);
		win_reference_btn.value_(0);
	});
});

// Playback Layout
var win_playback = GridLayout.rows(
	[
		StaticText().string_("Set BPM (Data Points per Minute)"),
		win_bpm_box
	], [
		win_play_btn,
		win_pause_btn,
		win_stop_btn
	]
);

//------------------------
//- End Playback section -
//------------------------

//------------------------
//- Start Window section -
//-----------------------------------
// Vertical aligned settings section
var win_settings = VLayout(
	StaticText().string_("Audio Settings").font_(h1),
	win_settings_audio,
	win_testing,
	StaticText().string_("Load Data").font_(h1),
	win_loading,
	StaticText().string_("Play Data").font_(h1),
	win_playback
);


//--------
// Window
// GUI element
var win = Window.new( "Air Quality Data Sonification" ).front
.layout_( win_settings )
.onClose_( { arg state;
	// free freq and amp bus
	fundfreq.free;
	fundamp.free;

	// free reference synth
	reference.free;

	// free test synths
	test.do( { arg synth;
		synth.free;
	});
	test_ampmul.do( { arg bus;
		bus.free;
	});

	// free sonify synth
	sonify.do( {arg synth;
		synth.free;
	});
	sonify_ampmul.do( {arg bus;
		bus.free;
	});
} );
//----------------------
//- End Window section -
//----------------------
)