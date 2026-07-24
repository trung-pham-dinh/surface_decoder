`include "prim.svh"

module logical_bit
    import common_pkg::*;
#(
) (
      input  logic                       clk
    , input  logic                       rst
    , input  logic                       start

    // flatten for top verilog file
    , input  logic [TORUS_L*TORUS_L-1:0] syndrome_update_flatten
    , output logic [TORUS_L*TORUS_L-1:0] syndrome_flatten
    , output logic [TORUS_L*TORUS_L-1:0] or_erasure_edges_flatten
);
    pe_state_e   pe_state;
    logic        spread_in_request;
    spread_cid_t spread_in_connect_cid;
    logic        spread_in_connect_parity;

    pe_status_t  pe_status_final, pe_status_final_pipe;
    logic        spread_request_any, spread_request_any_pipe;

    logic [TORUS_L-1:0][TORUS_L-1:0] syndrome_update;
    logic [TORUS_L-1:0][TORUS_L-1:0] syndrome;
    logic [TORUS_L-1:0][TORUS_L-1:0] or_erasure_edges;


    controller controller(
        .clk                      (clk                     ),   
        .rst                      (rst                     ),   
        .pe_status_final          (pe_status_final         ),       
        .spread_request_any       (spread_request_any      ),          
        .start                    (start                   ),  
                                   
        .pe_state                 (pe_state                ),
        .spread_in_request        (spread_in_request       ),         
        .spread_in_connect_cid    (spread_in_connect_cid   ),             
        .spread_in_connect_parity (spread_in_connect_parity)                
    );

    generate
        for (genvar i=0; i<TORUS_L; i=i+1) begin
            for (genvar j=0; j<TORUS_L; j=j+1) begin
                assign syndrome_flatten[i*TORUS_L+j]         = syndrome[i][j];
                assign syndrome_update[i][j]                 = syndrome_update_flatten[i*TORUS_L+j];
                assign or_erasure_edges_flatten[i*TORUS_L+j] = or_erasure_edges[i][j];
            end
        end
    endgenerate

    torus torus(
        .clk                      (clk                     ),   
        .rst                      (rst                     ),   

        .pe_state                 (pe_state                ),        
        .spread_in_request        (spread_in_request       ),                      
        .spread_in_connect_cid    (spread_in_connect_cid   ),                      
        .spread_in_connect_parity (spread_in_connect_parity),                      

        .syndrome_update          (syndrome_update         ),                
        .syndrome                 (syndrome                ),                
        .or_erasure_edges         (or_erasure_edges_flatten), 

        .pe_status_final          (pe_status_final         ), 
        .spread_request_any       (spread_request_any      )
    );
endmodule
