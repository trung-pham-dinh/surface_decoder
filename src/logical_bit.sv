`include "prim.svh"

module logical_bit
    import common_pkg::*;
#(
) (
      input  logic                            clk
    , input  logic                            rst
    , input  logic                            start
    , input  logic [TORUS_L-1:0][TORUS_L-1:0] syndrome_update
    , output logic [TORUS_L-1:0][TORUS_L-1:0] syndrome
);
    pe_state_e   pe_state;
    logic        spread_in_request;
    merged_cid_t spread_in_merge_cid;
    logic        spread_in_merge_parity;

    pe_status_t  pe_status_final, pe_status_final_pipe;
    logic        spread_request_final, spread_request_final_pipe;

    `PRIM_FF_RST(pe_status_final_pipe     , pe_status_final     , rst, clk, '0)
    `PRIM_FF_RST(spread_request_final_pipe, spread_request_final, rst, clk, '0)
    assign spread_in_request      = spread_request_final_pipe;
    assign spread_in_merge_cid    = pe_status_final_pipe.spread_out_merge_cid;
    assign spread_in_merge_parity = pe_status_final_pipe.spread_out_merge_parity;

    assign pe_state = (~start) ? PE_IDLE : (spread_request_final) ? PE_SPREAD : PE_GROW;

    torus torus(
        .clk                    (clk                    ),   
        .rst                    (rst                    ),   

        .pe_state               (pe_state               ),        
        .spread_in_request      (spread_in_request      ),                      
        .spread_in_merge_cid    (spread_in_merge_cid    ),                      
        .spread_in_merge_parity (spread_in_merge_parity ),                      

        .syndrome_update        (syndrome_update        ),                
        .syndrome               (syndrome               ),                

        .pe_status_final        (pe_status_final        ), 
        .spread_request_final   (spread_request_final   )
    );
endmodule
