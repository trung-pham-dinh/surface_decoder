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
    spread_cid_t spread_in_connect_cid;
    logic        spread_in_connect_parity;

    pe_status_t  pe_status_final, pe_status_final_pipe;
    logic        spread_request_any, spread_request_any_pipe;


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

    torus torus(
        .clk                      (clk                     ),   
        .rst                      (rst                     ),   

        .pe_state                 (pe_state                ),        
        .spread_in_request        (spread_in_request       ),                      
        .spread_in_connect_cid    (spread_in_connect_cid   ),                      
        .spread_in_connect_parity (spread_in_connect_parity),                      

        .syndrome_update          (syndrome_update         ),                
        .syndrome                 (syndrome                ),                

        .pe_status_final          (pe_status_final         ), 
        .spread_request_any       (spread_request_any      )
    );
endmodule
