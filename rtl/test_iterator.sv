/*
 *  Bounding Box Sample Test Iteration
 *
 *  Inputs:
 *    BBox and triangle Information
 *
 *  Outputs:
 *    Subsample location and triangle Information
 *
 *  Function:
 *    Iterate from left to right bottom to top
 *    across the bounding box.
 *
 *    While iterating set the halt signal in
 *    order to hold the bounding box pipeline in
 *    place.
 *
 *
 * Long Description:
 *    The iterator starts in the waiting state,
 *    when a valid triangle bounding box
 *    appears at the input. It will enter the
 *    testing state the next cycle with a
 *    sample equivelant to the lower left
 *    cooridinate of the bounding box.
 *
 *    While in the testing state, the next sample
 *    for each cycle should be one sample interval
 *    to the right, except when the current sample
 *    is at the right edge.  If the current sample
 *    is at the right edge, the next sample should
 *    be one row up.  Additionally, if the current
 *    sample is on the top row and the right edge,
 *    next cycles sample should be invalid and
 *    equivelant to the lower left vertice and
 *    next cycles state should be waiting.
 *
 *
 *   Author: John Brunhaver
 *   Created:      Thu 07/23/09
 *   Last Updated: Tue 10/01/10
 *
 *   Copyright 2009 <jbrunhaver@gmail.com>
 *
 */

/* ***************************************************************************
 * Change bar:
 * -----------
 * Date           Author    Description
 * Sep 19, 2012   jingpu    ported from John's original code to Genesis
 *
 * ***************************************************************************/

/* A Note on Signal Names:
 *
 * Most signals have a suffix of the form _RxxN
 * where R indicates that it is a Raster Block signal
 * xx indicates the clock slice that it belongs to
 * and N indicates the type of signal that it is.
 * H indicates logic high, L indicates logic low,
 * U indicates unsigned fixed point, and S indicates
 * signed fixed point.
 *
 * For all the signed fixed point signals (logic signed [`$sig_fig`-1:0]),
 * their highest `$sig_fig-$radix` bits, namely [`$sig_fig-1`:`$radix`]
 * represent the integer part of the fixed point number,
 * while the lowest `$radix` bits, namely [`$radix-1`:0]
 * represent the fractional part of the fixed point number.
 *
 *
 *
 * For signal subSample_RnnnnU (logic [3:0])
 * 1000 for  1x MSAA eq to 1 sample per pixel
 * 0100 for  4x MSAA eq to 4 samples per pixel,
 *              a sample is half a pixel on a side
 * 0010 for 16x MSAA eq to 16 sample per pixel,
 *              a sample is a quarter pixel on a side.
 * 0001 for 64x MSAA eq to 64 samples per pixel,
 *              a sample is an eighth of a pixel on a side.
 *
 */

module test_iterator
#(
    parameter SIGFIG = 24, // Bits in color and position.
    parameter RADIX = 10, // Fraction bits in color and position
    parameter VERTS = 3, // Maximum Vertices in triangle
    parameter AXIS = 3, // Number of axis foreach vertex 3 is (x,y,z).
    parameter COLORS = 3, // Number of color channels
    parameter PIPE_DEPTH = 1, // How many pipe stages are in this block
    parameter MOD_FSM = 0 // Use Modified FSM to eliminate a wait state
)
(
    //Input Signals
    input logic signed [SIGFIG-1:0]     tri_R13S[VERTS-1:0][AXIS-1:0], //triangle to Iterate Over
    input logic unsigned [SIGFIG-1:0]   color_R13U[COLORS-1:0] , //Color of triangle
    input logic signed [SIGFIG-1:0]     box_R13S[1:0][1:0], //Box to iterate for subsamples
    input logic                             validTri_R13H, //triangle is valid

    //Control Signals
    input logic [3:0]   subSample_RnnnnU , //Subsample width
    output logic        halt_RnnnnL , //Halt -> hold current microtriangle
    //Note that this block generates
    //Global Signals
    input logic clk, // Clock
    input logic rst, // Reset

    //Outputs
    output logic signed [SIGFIG-1:0]    tri_R14S[VERTS-1:0][AXIS-1:0], //triangle to Sample Test
    output logic unsigned [SIGFIG-1:0]  color_R14U[COLORS-1:0] , //Color of triangle
    output logic signed [SIGFIG-1:0]    sample_R14S[1:0], //Sample Location to Be Tested
    output logic                            validSamp_R14H //Sample and triangle are Valid
);

    // This module implement a Moore machine to iterarte sample points in bbox
    // Recall: a Moore machine is an FSM whose output values are determined
    // solely by its current state.
    // A simple way to build a Moore machine is to make states for every output
    // and the values of the current states are the outputs themselves

    // Now we create the signals for the next states of each outputs and
    // then instantiate registers for storing these states
    logic signed [SIGFIG-1:0]       next_tri_R14S[VERTS-1:0][AXIS-1:0];
    logic unsigned  [SIGFIG-1:0]    next_color_R14U[COLORS-1:0] ;
    logic signed [SIGFIG-1:0]       next_sample_R14S[1:0];
    logic                               next_validSamp_R14H;
    logic                               next_halt_RnnnnL;


    localparam LSB_CUT = 0;
    localparam MSB_CUT = 0;

    // Instantiate registers for storing these states
    dff3 #(
        .WIDTH(SIGFIG),
        .ARRAY_SIZE1(VERTS),
        .ARRAY_SIZE2(AXIS),
        .PIPE_DEPTH(1),
        .RETIME_STATUS(0)
    )
    d301
    (
        .clk    (clk            ),
        .reset  (rst            ),
        .en     (1'b1           ),
        .in     (next_tri_R14S  ),
        .out    (tri_R14S       )
    );

    dff2 #(
        .WIDTH(SIGFIG),
        .ARRAY_SIZE(COLORS),
        .PIPE_DEPTH(1),
        .RETIME_STATUS(0)
    )
    d302
    (
        .clk    (clk            ),
        .reset  (rst            ),
        .en     (1'b1           ),
        .in     (next_color_R14U),
        .out    (color_R14U     )
    );

    dff2 #(
        .WIDTH(SIGFIG),
        .ARRAY_SIZE(2),
        .PIPE_DEPTH(1),
        .RETIME_STATUS(0)
    )
    d303
    (
        .clk    (clk                ),
        .reset  (rst                ),
        .en     (1'b1               ),
        .in     (next_sample_R14S   ),
        .out    (sample_R14S        )
    );

    dff #(
        .WIDTH(2),
        .PIPE_DEPTH(1),
        .RETIME_STATUS(0) // No retime
    )
    d304
    (
        .clk    (clk                                    ),
        .reset  (rst                                    ),
        .en     (1'b1                                   ),
        .in     ({next_validSamp_R14H, next_halt_RnnnnL}),
        .out    ({validSamp_R14H, halt_RnnnnL}          )
    );
    // Instantiate registers for storing these states

    typedef enum logic {
                            WAIT_STATE,
                            TEST_STATE
                        } state_t;
generate
if(MOD_FSM == 0) begin // Using baseline FSM
    //////
    //////  RTL code for original FSM Goes Here
    //////

    // To build this FSM we want to have two more state: one is the working
    // status of this FSM, and the other is the current bounding box where
    // we iterate sample points

    // define two more states, box_R14S and state_R14H
    logic signed [SIGFIG-1:0]   box_R14S[1:0][1:0];    		// the state for current bounding box
    logic signed [SIGFIG-1:0]   next_box_R14S[1:0][1:0];

    state_t                     state_R14H;     //State Designation (Waiting or Testing)
    state_t                     next_state_R14H;        //Next Cycles State

    dff3 #(
        .WIDTH(SIGFIG),
        .ARRAY_SIZE1(2),
        .ARRAY_SIZE2(2),
        .PIPE_DEPTH(1),
        .RETIME_STATUS(0)
    )
    d305
    (
        .clk    (clk            ),
        .reset  (rst            ),
        .en     (1'b1           ),
        .in     (next_box_R14S  ),
        .out    (box_R14S       )
    );

    always_ff @(posedge clk, posedge rst) begin
        if(rst) begin
            state_R14H <= WAIT_STATE;
        end
        else begin
            state_R14H <= next_state_R14H;
        end
    end

    // define some helper signals
    logic signed [SIGFIG-1:0]   next_up_samp_R14S[1:0]; //If jump up, next sample
    logic signed [SIGFIG-1:0]   next_rt_samp_R14S[1:0]; //If jump right, next sample
    logic signed [SIGFIG-1:0]   next_lt_samp_R14S[1:0]; //If jump left, next sample
    logic                       at_right_edg_R14H;      //Current sample at right edge of bbox?
    logic                       at_top_edg_R14H;        //Current sample at top edge of bbox?
    logic                       at_bottom_edg_R14H;       //Current sample at bottom edge of bbox?   
    logic                       at_end_box_R14H;        //Current sample at end of bbox?
    logic                       inside_tri_R14H;            //Current sample outside of triangle?
    logic signed [SIGFIG-1:0]   tri_shift_bb[VERTS-1:0][1:0]; //Shifted triangle
    logic [2:0]                 less_than_0_ornot_bb; //Is the sample inside the triangle?
    logic [1:0]                 left0_right1; //If left, 0, if right, 1
    logic                       next_tri_seen; //if we seen a triangle  
    logic                       tri_seen; //if we seen a triangle



    always_ff @(posedge clk, posedge rst) begin
        if(rst) begin
            next_tri_seen <= 1'b0;
            tri_seen <= 1'b0;
        end
        else begin
            tri_seen <= next_tri_seen;
        end
    end
    //////
    ////// First calculate the values of the helper signals using CURRENT STATES
    //////

    // check the comments 'A Note on Signal Names'
    // at the begining of the module for the help on
    // understanding the signals here
    logic [SIGFIG-1:0] increment;
    always_comb begin
        increment = 0;
        case(subSample_RnnnnU)
            4'b1000: begin
                //1x MSAA eq. to 1 sample per pixel
                //no rounding needed
                // increment = 12'b010000000000;
                increment = {1'b1, {RADIX{1'b0}}};
            end
            4'b0100: begin
                //4x MSAA eq to 4 samples per pixel, a sample is half a pixel on a side
                // increment = 12'b001000000000;
                increment = {1'b1, {RADIX-1{1'b0}}};
            end
            4'b0010: begin
                //16x MSAA eq to 16 sample per pixel, a sample is a quarter pixel on a side.
                // increment = 12'b000100000000;
                increment = {1'b1, {RADIX-2{1'b0}}};
            end
            4'b0001: begin
                //64x MSAA eq to 64 samples per pixel, a sample is an eighth of a pixel on a side.
                // increment = 12'b000010000000;
                increment = {1'b1, {RADIX-3{1'b0}}};
            end
            default: begin
                increment = 0;
            end
        endcase
    end

    logic [2:0] less_than_0_ornot_bb_R13H;
    logic signed [SIGFIG-1:0]       tri_shift_R13S[VERTS-1:0][1:0]; 
    logic signed [SIGFIG-1:0]       centroid[AXIS-1:0];
    logic frontfacing;
    logic [SIGFIG-1:0] total_frontfacing_samples;
    always_comb begin
        centroid[0] = (box_R13S[0][0] + box_R13S[1][0]) >>> 1;
        centroid[1] = (box_R13S[0][1] + box_R13S[1][1]) >>> 1;

        tri_shift_R13S[0][0] = tri_R13S[0][0] - centroid[0];
        tri_shift_R13S[0][1] = tri_R13S[0][1] - centroid[1];
        tri_shift_R13S[1][0] = tri_R13S[1][0] - centroid[0];
        tri_shift_R13S[1][1] = tri_R13S[1][1] - centroid[1];
        tri_shift_R13S[2][0] = tri_R13S[2][0] - centroid[0];
        tri_shift_R13S[2][1] = tri_R13S[2][1] - centroid[1];

        // if ((tri_R13S[1][0] - tri_R13S[0][0])[SIGFIG-1] ^ (tri_R13S[2][1] - tri_R13S[1][1])[SIGFIG-1]) && ((tri_R13S[1][1] - tri_R13S[0][1])[SIGFIG-1] == (tri_R13S[2][0] - tri_R13S[1][0])[SIGFIG-1]) begin  
        //     frontfacing = 1;
        // end
        // else if ((tri_R13S[1][0] - tri_R13S[0][0])[SIGFIG-1] == (tri_R13S[2][1] - tri_R13S[1][1])[SIGFIG-1]) && ((tri_R13S[1][1] - tri_R13S[0][1])[SIGFIG-1] ^ (tri_R13S[2][0] - tri_R13S[1][0])[SIGFIG-1]) begin
        //     frontfacing = 1;
        // end
        // else begin
        //     frontfacing = (tri_R13S[1][0] - tri_R13S[0][0]) * (tri_R13S[2][1] - tri_R13S[1][1]) < (tri_R13S[1][1] - tri_R13S[0][1]) * (tri_R13S[2][0] - tri_R13S[1][0]);;
        // end

        
        // top4bits[0] = tri_shift_R13S[0][0][SIGFIG-1:SIGFIG-4];
        // top4bits[1] = tri_shift_R13S[0][1][SIGFIG-1:SIGFIG-4];
        // top4bits[2] = tri_shift_R13S[1][0][SIGFIG-1:SIGFIG-4];
        // top4bits[3] = tri_shift_R13S[1][1][SIGFIG-1:SIGFIG-4];
        // top4bits[4] = tri_shift_R13S[2][0][SIGFIG-1:SIGFIG-4];
        // top4bits[5] = tri_shift_R13S[2][1][SIGFIG-1:SIGFIG-4];
        // if ((top4bits[0] != 4'h0) && (top4bits[0] != 4'hf))  bigtriangle_exists = 1;
        // else bigtriangle_exists = 0;
        // if (tri_shift_R13S[0][0][SIGFIG-4 +: 4] != 4'b0000 || (tri_shift_R13S[0][0][SIGFIG-4 +: 4] != 4'b1111)) begin
        //     bigtriangle_exists = 1;
        // end else bigtriangle_exists = 0;
           
        // if (((tri_shift_R13S[0][0][SIGFIG-1:SIGFIG-4] != 4'b0000) && (tri_shift_R13S[0][1][SIGFIG-1:SIGFIG-4] != 4'b0000) &&(tri_shift_R13S[1][0][SIGFIG-1:SIGFIG-4] != 4'b0000) &&(tri_shift_R13S[1][1][SIGFIG-1:SIGFIG-4] != 4'b0000) &&(tri_shift_R13S[2][0][SIGFIG-1:SIGFIG-4] != 4'b0000) &&(tri_shift_R13S[2][1][SIGFIG-1:SIGFIG-4] != 4'b0000)) 
        //     && ((tri_shift_R13S[0][0][SIGFIG-1:SIGFIG-4] != 4'b1111) && (tri_shift_R13S[0][1][SIGFIG-1:SIGFIG-4] != 4'b1111) &&(tri_shift_R13S[1][0][SIGFIG-1:SIGFIG-4] != 4'b1111) &&(tri_shift_R13S[1][1][SIGFIG-1:SIGFIG-4] != 4'b1111) &&(tri_shift_R13S[2][0][SIGFIG-1:SIGFIG-4] != 4'b1111) &&(tri_shift_R13S[2][1][SIGFIG-1:SIGFIG-4] != 4'b1111)))begin
        //     bigtriangle_exists = 0;
        // end
        // else begin
        //     bigtriangle_exists = 1;
        // end
        // backfacing_1[0] = signed'(signed'(tri_shift_R13S[1][0][SIGFIG-MSB_CUT-1:LSB_CUT]) - signed'(tri_shift_R13S[0][0][SIGFIG-MSB_CUT-1:LSB_CUT]));
        // backfacing_1[1] = signed'(signed'(tri_shift_R13S[2][1][SIGFIG-MSB_CUT-1:LSB_CUT]) - signed'(tri_shift_R13S[1][1][SIGFIG-MSB_CUT-1:LSB_CUT]));
        // backfacing_1[2] = signed'(signed'(tri_shift_R13S[1][1][SIGFIG-MSB_CUT-1:LSB_CUT]) - signed'(tri_shift_R13S[0][1][SIGFIG-MSB_CUT-1:LSB_CUT]));
        // backfacing_1[3] = signed'(signed'(tri_shift_R13S[2][0][SIGFIG-MSB_CUT-1:LSB_CUT]) - signed'(tri_shift_R13S[1][0][SIGFIG-MSB_CUT-1:LSB_CUT]));
        // backfacing = (backfacing_1[0] * backfacing_1[1]) > (backfacing_1[2] * backfacing_1[3]);
        // this is working
        // backfacing = signed'((signed'(tri_shift_R13S[1][0][SIGFIG-MSB_CUT-1:LSB_CUT]) - signed'(tri_shift_R13S[0][0][SIGFIG-MSB_CUT-1:LSB_CUT]))) * signed'((signed'(tri_shift_R13S[2][1][SIGFIG-MSB_CUT-1:LSB_CUT]) - signed'(tri_shift_R13S[1][1][SIGFIG-MSB_CUT-1:LSB_CUT]))) > signed'((signed'(tri_shift_R13S[1][1][SIGFIG-MSB_CUT-1:LSB_CUT]) - signed'(tri_shift_R13S[0][1][SIGFIG-MSB_CUT-1:LSB_CUT]))) * signed'((signed'(tri_shift_R13S[2][0][SIGFIG-MSB_CUT-1:LSB_CUT]) - signed'(tri_shift_R13S[1][0][SIGFIG-MSB_CUT-1:LSB_CUT])));
        // if (!backfacing) begin
        //     total_frontfacing_samples = (box_R13S[1][0] - box_R13S[0][0] + 1)*(box_R13S[1][1] - box_R13S[0][1] + 1);
        end
    always_comb begin
        // START CODE HERE
        // first set flags
        
        at_right_edg_R14H = sample_R14S[0] == box_R14S[1][0];
        at_left_edg_R14H = sample_R14S[0] == box_R14S[0][0];
        at_top_edg_R14H = sample_R14S[1] == box_R14S[1][1];
        at_bottom_edg_R14H = sample_R14S[1] == box_R14S[0][1];
        at_end_box_R14H = ((sample_R14S[0] == box_R14S[1][0]) && (sample_R14S[1] == box_R14S[1][1]));

        // set next_sample_up and next_sample_rt
        next_up_samp_R14S[0] = box_R14S[0][0];
        next_up_samp_R14S[1] = sample_R14S[1] + increment;
        next_rt_samp_R14S[0] = sample_R14S[0] + increment;
        next_rt_samp_R14S[1] = sample_R14S[1];
        next_lt_samp_R14S[0] = sample_R14S[0] - increment;
        next_lt_samp_R14S[1] = sample_R14S[1];
        next_up_left_samp_R14S[0] = sample_R14S[0] - increment;
        next_up_left_samp_R14S[1] = sample_R14S[1] + increment;
        next_up_rt_samp_R14S[0] = sample_R14S[0] + increment;
        next_up_rt_samp_R14S[1] = sample_R14S[1] + increment;

        // set next_sample
        // if (at_right_edg_R14H == 1'b1) begin
        //     next_sample_R14S = next_up_samp_R14S;
        // end
        // else begin
        //     next_sample_R14S = next_rt_samp_R14S;
        // end


        // at_right_edg_R14H = 1'b0;
        // at_top_edg_R14H = 1'b0;
        // at_end_box_R14H = 1'b0;
        // //starting point
        // if (state_R14H == WAIT_STATE && validTri_R13H) begin
        //     next_sample_R14S[0] = box_R13S[0][0];
        //     next_sample_R14S[1] = box_R13S[0][1];
        //     // next_validSamp_R14H = 1'b1;
        // end
        // //check if at end of box
        // else if (state_R14H == TEST_STATE && sample_R14S[0] == box_R14S[1][0] && sample_R14S[1] == box_R14S[1][1]) begin
        //     at_end_box_R14H = 1'b1;
        //     // next_validSamp_R14H = 1'b0;
        // end
        // //check if at right edge
        // else if (state_R14H == TEST_STATE && sample_R14S[0] == box_R14S[1][0]) begin
        //     // next_up_samp_R14S[0] = box_R14S[0][0];
        //     // next_up_samp_R14S[1] = sample_R14S[1] + increment;
        //     next_sample_R14S[0] = box_R14S[0][0];
        //     next_sample_R14S[1] = sample_R14S[1] + increment;
        //     at_right_edg_R14H = 1'b1;
        //     // next_validSamp_R14H = 1'b1;
        // end
        // //check if at top edge
        // else if (state_R14H == TEST_STATE && sample_R14S[1] == box_R14S[1][1]) begin
        //     // next_rt_samp_R14S[0] = sample_R14S[0] + increment;
        //     // next_rt_samp_R14S[1] = sample_R14S[1];
        //     // next_up_samp_R14S[0] = sample_R14S[0] + increment;
        //     // next_up_samp_R14S[1] = sample_R14S[1];
        //     next_sample_R14S[0] = sample_R14S[0] + increment;
        //     next_sample_R14S[1] = sample_R14S[1];
        //     at_top_edg_R14H = 1'b1;
        //     // next_validSamp_R14H = 1'b1;
        // end
        // else begin
        //     // next_rt_samp_R14S[0] = sample_R14S[0] + increment;
        //     // next_rt_samp_R14S[1] = sample_R14S[1];
        //     next_sample_R14S[0] = sample_R14S[0] + increment;
        //     next_sample_R14S[1] = sample_R14S[1];
        //     at_right_edg_R14H = 1'b0;
        //     at_top_edg_R14H = 1'b0;
        //     at_end_box_R14H = 1'b0;
        //     // next_validSamp_R14H = 1'b1;
        // end
        


        
        
        // if (!validTri_R13H) begin
        //     next_validSamp_R14H = 1'b0;
        // end
        // next_sample_R14S[0] = next_rt_samp_R14S[0];
        // next_sample_R14S[1] = next_up_samp_R14S[1];
        // END CODE HERE
    end

    //////
    ////// Then complete the following combinational logic defining the
    ////// next states
    //////

    ////// COMPLETE THE FOLLOW ALWAYS_COMB BLOCK

    // Combinational logic for state transitions
    always_comb begin
        // START CODE HERE
        // Try using a case statement on state_R14H
        case (state_R14H)
            WAIT_STATE: begin
                next_tri_R14S = tri_R13S;
                next_box_R14S = box_R13S;
                next_color_R14U = color_R13U;
                if (validTri_R13H) begin
                    next_state_R14H = TEST_STATE;
                    next_halt_RnnnnL = 1'b0;
                    next_validSamp_R14H = 1'b1;
                    next_sample_R14S = box_R13S[0];
                    left0_right1 = 1;
                    next_tri_seen = 0;
                end
                else begin
                    next_state_R14H = WAIT_STATE;
                    next_halt_RnnnnL = 1'b1;
                    next_validSamp_R14H = 1'b0;
                end
            end
            TEST_STATE: begin
                next_tri_R14S = tri_R14S;
                next_box_R14S = box_R14S;
                next_color_R14U = color_R14U;

                

                if (at_end_box_R14H) begin
                    next_state_R14H = WAIT_STATE;
                    next_halt_RnnnnL = 1'b1;
                    next_validSamp_R14H = 1'b0;
                end
                
                else begin
                    next_state_R14H = TEST_STATE;
                    next_halt_RnnnnL = 1'b0;
                    next_validSamp_R14H = 1'b1;

                    //test if outside of triangle
                    //if first term is negative and second term is positive, then the dist is negative
                    if ((tri_shift_bb[0][0][SIGFIG-1] ^ tri_shift_bb[1][1][SIGFIG-1]) && (tri_shift_bb[1][0][SIGFIG-1] == tri_shift_bb[0][1][SIGFIG-1])) begin
                        less_than_0_ornot_bb[0] = 1;
                    end 
                    // if positive, first term has to be positive and second term has to be negative
                    else if ((tri_shift_bb[0][0][SIGFIG-1] == tri_shift_bb[1][1][SIGFIG-1]) && (tri_shift_bb[1][0][SIGFIG-1] ^ tri_shift_bb[0][1][SIGFIG-1])) begin
                        less_than_0_ornot_bb[0] = 0;
                    end else
                    // do the multiplication
                    begin
                        less_than_0_ornot_bb[0] = ((tri_shift_bb[0][0] * tri_shift_bb[1][1]) - (tri_shift_bb[1][0] * tri_shift_bb[0][1]))<=0?1:0;
                    end

                    // 
                    if ((tri_shift_bb[1][0][SIGFIG-1] ^ tri_shift_bb[2][1][SIGFIG-1]) && (tri_shift_bb[2][0][SIGFIG-1] == tri_shift_bb[1][1][SIGFIG-1])) begin
                        less_than_0_ornot_bb[1] = 1;
                    end 
                    // if positive, first term has to be positive and second term has to be negative
                    else if ((tri_shift_bb[1][0][SIGFIG-1] == tri_shift_bb[2][1][SIGFIG-1]) && (tri_shift_bb[2][0][SIGFIG-1] ^ tri_shift_bb[1][1][SIGFIG-1])) begin
                        less_than_0_ornot_bb[1] = 0;
                    end else
                    // do the multiplication
                    begin
                        less_than_0_ornot_bb[1] = ((tri_shift_bb[1][0] * tri_shift_bb[2][1]) - (tri_shift_bb[2][0] * tri_shift_bb[1][1]))<0?1:0;
                    end

                    if ((tri_shift_bb[2][0][SIGFIG-1] ^ tri_shift_bb[0][1][SIGFIG-1]) && (tri_shift_bb[0][0][SIGFIG-1] == tri_shift_bb[2][1][SIGFIG-1])) begin
                        less_than_0_ornot_bb[2] = 1;
                    end 
                    // if positive, first term has to be positive and second term has to be negative
                    else if ((tri_shift_bb[2][0][SIGFIG-1] == tri_shift_bb[0][1][SIGFIG-1]) && (tri_shift_bb[0][0][SIGFIG-1] ^ tri_shift_bb[2][1][SIGFIG-1])) begin
                        less_than_0_ornot_bb[2] = 0;
                    end else
                    // do the multiplication
                    begin
                        less_than_0_ornot_bb[2] = ((tri_shift_bb[2][0] * tri_shift_bb[0][1]) - (tri_shift_bb[0][0] * tri_shift_bb[2][1]))<=0?1:0;
                    end

                    inside_tri_R14H = (less_than_0_ornot_bb[0]) && (less_than_0_ornot_bb[1]) && (less_than_0_ornot_bb[2]);
                    
                    if (inside_tri_R14H && !tri_seen) next_tri_seen = 1;
                    else next_tri_seen = 0;



                    if (at_bottom_edg_R14H && !tri_seen) begin
                        left0_right1 = 1;
                        next_sample_R14S = next_rt_samp_R14S;
                    end
                    else if (at_bottom_edg_R14H && inside_tri_R14H) begin
                        left0_right1 = 1;
                        next_sample_R14S = next_rt_samp_R14S
                    end
                    else if (at_bottom_edg_R14H && !inside_tri_R14H && tri_seen) begin
                        left0_right1 = 0;
                        next_sample_R14S = next_up_left_samp_R14S;
                    end




                    
                    if (at_right_edg_R14H) begin
                        next_sample_R14S = next_up_samp_R14S;
                    end
                    else begin
                        next_sample_R14S = next_rt_samp_R14S;
                    end
                end
            end
            default: begin
                next_state_R14H = WAIT_STATE;
            end
        endcase
        // END CODE HERE
    end // always_comb

    //Assertions for testing FSM logic

    // Write assertions to verify your FSM transition sequence
    // Can you verify that:
    // 1) A validTri_R13H signal causes a transition from WAIT state to TEST state
    // 2) An end_box_R14H signal causes a transition from TEST state to WAIT state
    // 3) What are you missing?

    //Your assertions goes here
    // START CODE HERE
    assert property (@(posedge clk) disable iff (rst) ((validTri_R13H && (state_R14H == WAIT_STATE)) -> (next_state_R14H == TEST_STATE)));
    assert property (@(posedge clk) disable iff (rst) ((at_end_box_R14H && (state_R14H == TEST_STATE)) -> ((next_state_R14H == WAIT_STATE))));
    // END CODE HERE
    // Assertion ends

    //////
    //////  RTL code for original FSM Finishes
    //////

    //Some Error Checking Assertions

    //Define a Less Than Property
    //
    //  a should be less than b
    property rb_lt( rst, a , b , c );
        @(posedge clk) rst | ((a<=b) | !c);
    endproperty

    //Check that Proposed Sample is in BBox
    // START CODE HERE
    assert property (@(posedge clk) disable iff (rst) (rb_lt(rst, next_box_R14S[0][0], next_sample_R14S[0], next_validSamp_R14H)));
    assert property (@(posedge clk) disable iff (rst) (rb_lt(rst, next_sample_R14S[0], next_box_R14S[1][0], next_validSamp_R14H)));
    assert property (@(posedge clk) disable iff (rst) (rb_lt(rst, next_box_R14S[0][1], next_sample_R14S[1], next_validSamp_R14H)));
    assert property (@(posedge clk) disable iff (rst) (rb_lt(rst, next_sample_R14S[1], next_box_R14S[1][1], next_validSamp_R14H)));
    // END CODE HERE
    //Check that Proposed Sample is in BBox

    //Error Checking Assertions
end 
else begin // Use modified FSM

    //////
    //////  RTL code for modified FSM Goes Here
    //////

    ////// PLACE YOUR CODE HERE

    //////
    //////  RTL code for modified FSM Finishes
    //////

end
endgenerate

endmodule



