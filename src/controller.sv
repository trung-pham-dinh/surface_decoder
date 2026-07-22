`include "prim.svh"

module controller 
    import common_pkg::*;
(
      input  logic          clk
    , input  logic          rst
    , input  pe_status_t    pe_status_final
    , input  logic          spread_request_any
    , input  logic          start

    , output pe_state_e     pe_state
    , output logic          spread_in_request
    , output spread_cid_t   spread_in_connect_cid
    , output logic          spread_in_connect_parity
);

    typedef enum logic [1:0] { 
        LOGICAL_IDLE,
        LOGICAL_GROW,
        LOGICAL_SPREAD,
        LOGICAL_WAIT
    } logical_state_e;

    logical_state_e state, state_next;
    logic           wait_start, wait_start_pipe;
    logic           wait_done;
    pe_status_t     pe_status_final_pipe;

    always_comb begin
        case (state)
            LOGICAL_IDLE: begin
                if(start) begin
                    state_next = LOGICAL_GROW;
                end
                else begin
                    state_next = state;
                end
                pe_state = PE_IDLE;
            end
            LOGICAL_GROW: begin
                if(spread_request_any) begin
                    state_next = LOGICAL_SPREAD;
                    pe_state   = PE_SPREAD;
                end
                else begin
                    state_next = state;
                    pe_state   = PE_GROW;
                end
            end
            LOGICAL_SPREAD: begin
                if (~spread_request_any) begin
                    state_next = LOGICAL_GROW;
                end
                else begin
                    state_next = LOGICAL_WAIT;
                end
                pe_state = PE_SPREAD;
            end
            LOGICAL_WAIT: begin
                if (wait_done) begin
                    state_next = LOGICAL_SPREAD;
                end
                else begin
                    state_next = state;
                end
                pe_state = PE_SPREAD;
            end
            default: begin
                state_next = state;
                pe_state   = PE_IDLE;
            end
        endcase 
        spread_in_request = (state_next == LOGICAL_WAIT) && (state == LOGICAL_SPREAD);
        wait_start = spread_in_request;
    end

    `PRIM_FF_RST(state          , state_next     , rst, clk, LOGICAL_IDLE)
    `PRIM_FF_RST(wait_start_pipe, wait_start     , rst, clk, '0)
    `PRIM_FF_RST(wait_done      , wait_start_pipe, rst, clk, '0)
    
    `PRIM_FF_RST(pe_status_final_pipe   , pe_status_final     , rst, clk, '0)

    assign spread_in_connect_cid    = pe_status_final_pipe.spread_out_connect_cid;
    assign spread_in_connect_parity = pe_status_final_pipe.spread_out_connect_parity;

endmodule