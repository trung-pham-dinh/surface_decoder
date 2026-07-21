//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Author     : (generated)
// Description: L x L toric-code lattice of PE vertices with
//              periodic (wrap-around) boundaries in both axes.
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
//
// Coordinate convention:
//   i = row index    (0 .. L-1)  -> top/bot axis
//   j = column index (0 .. L-1)  -> left/right axis
//
// Periodic neighbors (torus):
//   right : (i          , (j+1)%L)
//   left  : (i          , (j-1)%L)
//   bot   : ((i+1)%L     , j     )
//   top   : ((i-1)%L     , j     )
//
// NOTE: this assumes `in_erasure_*` are INPUTS on the pe module
//       (see conversation). If they are truly outputs, wiring is
//       impossible and the pe interface must be fixed first.
//

`include "prim.svh"
module torus
    import common_pkg::*;
#(
) (
      input  logic                                   clk
    , input  logic                                   rst

    // Global broadcast to every PE
    , input  pe_state_e                              pe_state
    , input  logic                                   spread_in_request     
    , input  merged_cid_t                            spread_in_merge_cid   
    , input  logic                                   spread_in_merge_parity

    // Per-PE syndrome interface (brought to top level)
    , input  logic [TORUS_L-1:0][TORUS_L-1:0]        syndrome_update 
    , output logic [TORUS_L-1:0][TORUS_L-1:0]        syndrome        

    , output pe_status_t pe_status_final
    , output logic       spread_request_final
);

    //-------------------------------------------------------------
    // Inter-PE nets
    //-------------------------------------------------------------
    // self_cid / self_cpar of each PE, read by its four neighbors
    cid_t [TORUS_L-1:0][TORUS_L-1:0] cid ;
    logic [TORUS_L-1:0][TORUS_L-1:0] cpar;

    // out_erasure_<dir> of each PE, read by the neighbor in <dir>
    logic [TORUS_L-1:0][TORUS_L-1:0] er_left ;
    logic [TORUS_L-1:0][TORUS_L-1:0] er_right;
    logic [TORUS_L-1:0][TORUS_L-1:0] er_top  ;
    logic [TORUS_L-1:0][TORUS_L-1:0] er_bot  ;

    //-------------------------------------------------------------
    // Instantiate the lattice
    //-------------------------------------------------------------
    logic        [TORUS_L-1:0][TORUS_L-1:0] spread_out_request; 
    merged_cid_t [TORUS_L-1:0][TORUS_L-1:0] spread_out_merge_cid;
    logic        [TORUS_L-1:0][TORUS_L-1:0] spread_out_merge_parity;

    pe_status_t [TORUS_L-1:0][TORUS_L-1:0] pe_status_lattice;
    pe_status_t [TORUS_L-1:0]              pe_status_row;
    logic [TORUS_L-1:0] [TORUS_L-1:0] spread_request_lattice;
    logic [TORUS_L-1:0] [TORUS_L-1:0] spread_request_lattice_colmasked;
    logic [TORUS_L-1:0] spread_request_row;
    logic [TORUS_L-1:0] spread_request_row_rowmasked;


    generate
        for (genvar i = 0; i < TORUS_L; i = i + 1) begin : g_lattice_row
            for (genvar j = 0; j < TORUS_L; j = j + 1) begin : g_lattice_col

                pe #(
                    // Each vertex starts as its own cluster: unique ID
                    .DEFAULT_CID ( cid_t'(i*TORUS_L + j) )
                ) u_pe (
                      .clk ( clk )
                    , .rst ( rst )

                    // ---- neighbor cluster-id inputs (periodic) ----
                    , .in_cid_left  ( cid[i][(j+TORUS_L-1)%TORUS_L] )
                    , .in_cid_right ( cid[i][(j+1)        %TORUS_L] )
                    , .in_cid_top   ( cid[(i+TORUS_L-1)%TORUS_L][j] )
                    , .in_cid_bot   ( cid[(i+1)        %TORUS_L][j] )

                    // ---- neighbor cluster-parity inputs ----
                    , .in_cpar_left  ( cpar[i][(j+TORUS_L-1)%TORUS_L] )
                    , .in_cpar_right ( cpar[i][(j+1)        %TORUS_L] )
                    , .in_cpar_top   ( cpar[(i+TORUS_L-1)%TORUS_L][j] )
                    , .in_cpar_bot   ( cpar[(i+1)        %TORUS_L][j] )

                    // ---- erasure inputs: neighbor's output toward me ----
                    // (assumes in_erasure_* are INPUTS)
                    , .in_erasure_left  ( er_right[i][(j+TORUS_L-1)%TORUS_L] )
                    , .in_erasure_right ( er_left [i][(j+1)        %TORUS_L] )
                    , .in_erasure_top   ( er_bot  [(i+TORUS_L-1)%TORUS_L][j] )
                    , .in_erasure_bot   ( er_top  [(i+1)        %TORUS_L][j] )

                    // ---- erasure outputs: my drive toward each neighbor ----
                    , .out_erasure_left  ( er_left [i][j] )
                    , .out_erasure_right ( er_right[i][j] )
                    , .out_erasure_top   ( er_top  [i][j] )
                    , .out_erasure_bot   ( er_bot  [i][j] )

                    // ---- self outputs ----
                    , .self_cid  ( cid [i][j] )
                    , .self_cpar ( cpar[i][j] )

                    // ---- global ----
                    , .pe_state        ( pe_state )
                    , .syndrome_update ( syndrome_update[i][j] )
                    , .syndrome        ( syndrome[i][j] )

                    // ---- spread (per-PE, exposed to top) ----
                    , .spread_in_request      ( spread_in_request)
                    , .spread_in_merge_cid    ( spread_in_merge_cid)
                    , .spread_in_merge_parity ( spread_in_merge_parity)
                    , .spread_out_request     ( spread_out_request[i][j])
                    , .spread_out_merge_cid   ( spread_out_merge_cid[i][j])
                    , .spread_out_merge_parity( spread_out_merge_parity[i][j])
                );

                always_comb begin
                    pe_status_lattice[i][j].spread_out_merge_cid    = spread_out_merge_cid[i][j];
                    pe_status_lattice[i][j].spread_out_merge_parity = spread_out_merge_parity[i][j];
                    spread_request_lattice[i][j]                    = spread_out_request[i][j];
                end
            end
            `PRIM_FIRST_RIGHT_1(spread_request_lattice_colmasked[i], spread_request_lattice[i])
        end
        `PRIM_FIRST_RIGHT_1(spread_request_row_rowmasked, spread_request_row)
    endgenerate

    generate
        always_comb begin
            for (int i = 0; i < TORUS_L; i+=1) begin: g_row
                pe_status_row[i] = '0;
                for (int j = 0; j < TORUS_L; j+=1) begin: g_col
                    pe_status_row[i] |= pe_status_lattice[i][j]
                                      & {$bits(pe_status_t){spread_request_lattice_colmasked[i][j]}};
                end
                spread_request_row[i] = |spread_request_lattice[i];
            end

            pe_status_final = '0;
            for (int i = 0; i < TORUS_L; i+=1) begin: g_row
                pe_status_final |= pe_status_row[i] 
                                 & {$bits(pe_status_t){spread_request_row[i]}};   
            end

            spread_request_final = |spread_request_row;
        end
    endgenerate

endmodule