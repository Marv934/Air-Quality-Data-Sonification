// This file is part of Air Quality Data Sonification.
//
// Air Quality Data Sonification is free software: you can redistribute
// it and/or modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// Air Quality Data Sonification is distributed in the hope that it will
// be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
// of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Air Quality Data Sonification.
// If not, see <http://www.gnu.org/licenses/>.

//-------
//- GUI -
//-------

//---------------
//- Init Busses -
//---------------
var fundfreq = Bus.control(s, 1); // fundamental frequency bus
var fundamp = Bus.control(s, 1);  // fundamental amplitude bus

//----------------------
//- Init Synth Handler -
//----------------------
var reference; // reference synth
var test; // test synth

//---------------------------------
//- Init GUI and Setup Appearance -
//---------------------------------

// set Fonts
var h1 = Font.new( size: 18, bold: true );

//-------------------------------
//- Start Audio setting section -
//--------------------------------
// Fundamental Frequency Settings
var spec_fundfreq = ControlSpec( 60, 10000, \exp, 1 ); // map slider (0 - 1) to frequency range

var win_fundfreq_box = NumberBox().align_( \right )
.action_({ arg num;
	// Set fundamental frequency bus
	fundfreq.value = num.value;
} )
.valueAction_( 440 ).clipLo_( 60 ).clipHi_( 10000 );

var win_fundfreq_slider = Slider()
.action_( {
	// set fundamental frequency box
	win_fundfreq_box.valueAction_( spec_fundfreq.map( win_fundfreq_slider.value ) )
} )
.value_( spec_fundfreq.unmap( 440 ) );

// Fundamental Amplitude Settings
var win_fundamp_box = NumberBox().align_( \right )
.action_({ arg num;
	// set fundamental amplitude bus
	fundamp.value = num.value/5;
} )
.valueAction_( 0.9 ).clipLo_( 0 ).clipHi_( 1 );

var win_fundamp_slider = Slider()
.action_( {
	// set fundamental amplidutde box
	win_fundamp_box.valueAction_( win_fundamp_slider.value )
} )
.value_( 0.9 );

// Frequency Mappig Selection
var array_scale = [
	[3/2, 9/4, 27/8, 81/16, 243/32, 729/64], // fifth shift
	[3/2, 9/8, 27/16, 81/64, 243/128, 729/512], // fifth shift, transposed into one Oktave
	[2, 3, 4, 5, 6, 7], // pure overtones
	[3/2, 81/64, 243/128, 4/3, 27/16, 9/8] // dur Tonic ( 5, 3, 7, 4, 6, 2 )
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
	[0, 20, 40, 50, 100, 150, 1200], // PM 10 micrometer
	[0, 10, 20, 25, 50, 75, 800] //PM 2.5 micrometer
];

var win_breakpoints_select = ListView()
.action_( { arg sel;
	// Set mapping from AQI to amplitude for each breakpoint
	aqi_spec = Array.fill( array_breakpoints[ sel.value].size - 1, {arg i;
		ControlSpec(
			array_breakpoints[sel.value][i],
			array_breakpoints[sel.value][i+1],
			\lin, 1
		);
	} );
})
.items_( [
	"PM 10  (P1)",
	"PM 2.5 (P2)",
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
)
.setMinRowHeight(1, 200);
//----------------------------
// End Audio setting section -
//----------------------------

//------------------------
// Start Testing section -
//------------------------
// Set data value slider
var test_ampmul = Array.fill( array_scale[ win_scale_select.value ].size, {arg i;
	// Amplitude Busses for each breakpoint
	Bus.control(s, 1).value_(0);
} );

var win_testdata_box = NumberBox().align_( \right )
.action_( { arg num;
	// Set Amplitude Busses
	aqi_spec.do( { arg spec, i;
		test_ampmul[i].value = ( spec.unmap( num.value ) );
	} );
} )
.valueAction_( 0 );

var win_testdata_slider = Slider().orientation_( \horizontal )
.action_( {
	// Mapping (slider 0-1 to AQImin - AQImax)
	var spec_testdata = ControlSpec(
		array_breakpoints[win_breakpoints_select.value][0],
		array_breakpoints[win_breakpoints_select.value][6],
		\lin, 1
	);
	// Set AQI box from slider
	win_testdata_box.valueAction_( spec_testdata.map( win_testdata_slider.value ) )
} )
.value_( 0 );

// Referene Tone Start/Stop Button
var win_reference_btn = Button()
.action_( { arg state;
	if( state.value == 1, { // Start reference
		reference = Synth( \Reference );
		reference.map(\freq, fundfreq.index);
		reference.map(\amp, fundamp.index);
	}, { // Stop reference
		reference.free;
		reference = nil;
	});
} )
.states_( [["Start Reference", Color.black, Color.green], ["Stop Reference", Color.black, Color.red]] );

// Referene Tone Start/Stop Button
var win_test_btn = Button()
.action_( { arg state;
	if( state.value == 1, { // Start test
		test = Array.fill( array_scale[ win_scale_select.value ].size, {arg i;
			Synth( \AQI, [\freqmul, array_scale[ win_scale_select.value ][i] ] )
			.map(\freq, fundfreq.index, \amp, fundamp.index, \ampmul, test_ampmul[i].index);
		} );
		aqi_spec.do( { arg spec, i;
			test_ampmul[i].value = ( spec.unmap( win_testdata_box.value ) );
		} );
	}, { // Stop test
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
	// File select Dialog
	FileDialog({ |paths|
		win_file_text.value = paths[0];
	}, {
		postln("Dialog was cancelled. Try again.");
	});
});

// Select Data colum
var win_datacolum_box = NumberBox().action_( ).value_(0).align_(\right);

var win_datacolum_text = StaticText().string_("No Data Loaded");

// Select Time colum
var win_timecolum_box = NumberBox().action_( ).value_(0).align_(\right);

var win_timecolum_text = StaticText().string_("No Data Loaded");

// Load Data
var data, timestamp;

var win_loaddata_btn = Button().states_( [["Load Data"]] )
.action_( {arg state;
	var raw_data;

	// Read Data
	raw_data = CSVFileReader.read( win_file_text.value, true );

	// Remove Header
	win_datacolum_text.string_(raw_data[0][win_datacolum_box.value]);
	win_timecolum_text.string_(raw_data[0][win_timecolum_box.value]);
	raw_data.removeAt(0);

	// Store requiered data
	data = Array.newClear;
	timestamp = Array.newClear;
	raw_data.do( {arg line, i;
		data = data.add(line[win_datacolum_box.value].asFloat);
		timestamp = timestamp.add(line[win_timecolum_box.value]);
	});
} );

// Data Loading Layout
var win_loading = GridLayout.rows(
	[
		win_file_btn,
		[ win_file_text, columns:2 ]
	], [
		StaticText().string_("Select Air Quality Data Colum"),
		win_datacolum_box,
		win_datacolum_text
	], [
		StaticText().string_("Select Timestamp Data Colum"),
		win_timecolum_box,
		win_timecolum_text
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

// Record Button
var recorder;

var win_record_btn = Button().states_( [["Record"], ["Record", Color.black, Color.red]])
.action_( {arg state;

	// check if recording
	if( state.value == 1, { // is not recording

		// init recorder
		thisProcess.platform.recordingsDir = "./recordings/";
		recorder = Recorder.new(s);
		recorder.recHeaderFormat_("wav");

		//start recorder
		recorder.record;
	}, { // is recording

		// stop recorder
		recorder.stopRecording;
	});
});

// Sonification Task
var task_sonify = Task({
	// Calculate waiting time
	var dt = 60/bpm;

	// Loop trough data
	data.do({ arg value, counter;
		"Timestamp: ".post;
		timestamp[counter].post;
		"; AQI: ".post;
		value.postln;

		// Map AQI to ampmul
		aqi_spec.do( { arg spec, i;
			sonify_ampmul[i].value = ( spec.unmap( value ) );
		} );
		dt.wait;
	});

	// Stop Synth
	sonify.do({ arg synth;
		synth.free;
	});
	sonify = nil;
	reference.free;
	reference = nil;
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
			sonify = nil;
			reference = nil;

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
			sonify = nil;
			reference = nil;
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
	], [
		[ win_record_btn, columns:3]
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

//------------------------
//- Start Server section -
//------------------------
SynthDef( \Reference, {arg freq = 440, amp = 0.5;
	Out.ar( [0, 1] , SinOsc.ar(freq, 0, amp, 0));
}).add;

SynthDef( \AQI, {arg freq = 440, freqmul = 1, amp = 0.5, ampmul = 1;
	Out.ar( [0, 1] , SinOsc.ar(freq * freqmul, 0, amp * ampmul, 0));
}).add;
//----------------------
//- End Server section -
//----------------------