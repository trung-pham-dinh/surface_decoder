`include "prim.svh"

module pe 
  import common_pkg::*;
#(
    parameter cid_t DEFAULT_CID = '0
) (
      input  logic         clk
    , input  logic         rst
    // Local communication (with 4 surrounding PEs)
      // IN
    , input  cid_t         in_cid_left
    , input  cid_t         in_cid_right
    , input  cid_t         in_cid_top
    , input  cid_t         in_cid_bot

    , input  logic         in_cpar_left
    , input  logic         in_cpar_right
    , input  logic         in_cpar_top
    , input  logic         in_cpar_bot

    , input  logic         in_erasure_left
    , input  logic         in_erasure_right
    , input  logic         in_erasure_top
    , input  logic         in_erasure_bot

    , output logic         out_erasure_left  
    , output logic         out_erasure_right
    , output logic         out_erasure_top   
    , output logic         out_erasure_bot   

      // OUT
    , output cid_t         self_cid
    , output logic         self_cpar

    // Global communication
    , input  pe_state_e    pe_state
    , input  logic         syndrome_update // pulse -> syndrome updated to 1
    , output logic         syndrome


    // Spread
    , input  logic         spread_in_request
    , input  merged_cid_t  spread_in_merge_cid
    , input  logic         spread_in_merge_parity

    , output logic         spread_out_request
    , output merged_cid_t  spread_out_merge_cid
    , output logic         spread_out_merge_parity
);
    logic self_cpar_next;
    cid_t self_cid_next;

//////////////////////////////////////////
// Grow and Merge request: 
//(Note: each point is also its own cluster at the beginning)
//////////////////////////////////////////
    logic merge_request_left, merge_request_right, merge_request_top, merge_request_bot  ;
    cid_t merge_cid_left, merge_cid_right, merge_cid_top, merge_cid_bot;
    logic is_merging_left, is_merging_right, is_merging_top, is_merging_bot;
    logic out_erasure_left_next, out_erasure_right_next, out_erasure_top_next, out_erasure_bot_next;  

    logic merge_request_any;
    cid_t dst_cid;
    logic dst_cpar,merge_cpar;
    logic is_full_grow, grow;
    logic grow_enable;


    always_comb begin
        merge_request_left  = in_erasure_left  & (in_cid_left  != self_cid);
        merge_request_right = in_erasure_right & (in_cid_right != self_cid);
        merge_request_top   = in_erasure_top   & (in_cid_top   != self_cid);
        merge_request_bot   = in_erasure_bot   & (in_cid_bot   != self_cid);

        merge_request_any = |{merge_request_left, merge_request_right, merge_request_top, merge_request_bot};

        merge_cid_left   = (merge_request_left ) ? in_cid_left  : NON_CID;
        merge_cid_right  = (merge_request_right) ? in_cid_right : NON_CID;
        merge_cid_top    = (merge_request_top  ) ? in_cid_top   : NON_CID;
        merge_cid_bot    = (merge_request_bot  ) ? in_cid_bot   : NON_CID;

        // Pick one request among the request
        if (merge_request_left) begin
            dst_cid  = in_cid_left;
            dst_cpar = in_cpar_left;
        end
        else if (merge_request_right) begin
            dst_cid  = in_cid_right;
            dst_cpar = in_cpar_right;
        end
        else if (merge_request_top) begin
            dst_cid  = in_cid_top;
            dst_cpar = in_cpar_top;
        end
        else begin
            dst_cid  = in_cid_bot;
            dst_cpar = in_cpar_bot;
        end

        is_merging_left  = dst_cid == in_cid_left ;
        is_merging_right = dst_cid == in_cid_right;
        is_merging_top   = dst_cid == in_cid_top  ;
        is_merging_bot   = dst_cid == in_cid_bot  ;

        merge_cpar = self_cpar ^ dst_cpar;

        is_full_grow = out_erasure_left & out_erasure_right & out_erasure_top & out_erasure_bot; 
        grow         = ~is_full_grow & self_cpar;

        // Only merge the one having the same cid as dst_cid among requests
        // Merge has higher priority than Grow
        out_erasure_left_next  = (merge_request_any & is_merging_left ) ? 1'b1 : (grow) ? 1'b1 : out_erasure_left ; 
        out_erasure_right_next = (merge_request_any & is_merging_right) ? 1'b1 : (grow) ? 1'b1 : out_erasure_right; 
        out_erasure_top_next   = (merge_request_any & is_merging_top  ) ? 1'b1 : (grow) ? 1'b1 : out_erasure_top  ; 
        out_erasure_bot_next   = (merge_request_any & is_merging_bot  ) ? 1'b1 : (grow) ? 1'b1 : out_erasure_bot  ; 
    end
    assign grow_enable = (pe_state == PE_GROW);

    `PRIM_FF_EN_RST(out_erasure_left , out_erasure_left_next , grow_enable, rst, clk, '0)
    `PRIM_FF_EN_RST(out_erasure_right, out_erasure_right_next, grow_enable, rst, clk, '0)
    `PRIM_FF_EN_RST(out_erasure_top  , out_erasure_top_next  , grow_enable, rst, clk, '0)
    `PRIM_FF_EN_RST(out_erasure_bot  , out_erasure_bot_next  , grow_enable, rst, clk, '0)

//////////////////////////////////////////
// Spread out/in
//////////////////////////////////////////
    merged_cid_t spread_out_merge_cid_next;
    logic spread_out_merge_parity_next;
    logic belong_cluster_left, belong_cluster_right, belong_cluster_top, belong_cluster_bot;
    logic belong_cluster_any;
    logic spread_request;
    logic is_spread_affected;

    always_comb begin
        belong_cluster_left  = (in_cid_left  == self_cid);
        belong_cluster_right = (in_cid_right == self_cid);
        belong_cluster_top   = (in_cid_top   == self_cid);
        belong_cluster_bot   = (in_cid_bot   == self_cid);

        belong_cluster_any = |{belong_cluster_left,belong_cluster_right, belong_cluster_top, belong_cluster_bot}; // more than one PEs per cluster
        spread_request = belong_cluster_any & merge_request_any;

        is_spread_affected = (self_cid inside {spread_in_merge_cid.src, spread_in_merge_cid.dst});
        //is_dst_spread_affected  = (spread_out_merge_cid_next.dst inside {spread_in_merge_cid.src, spread_in_merge_cid.dst});
        //is_src_spread_affected  = (spread_out_merge_cid_next.src inside {spread_in_merge_cid.src, spread_in_merge_cid.dst});

        spread_out_merge_cid_next.dst = dst_cid ;
        spread_out_merge_cid_next.src = self_cid;
        spread_out_merge_parity_next  = merge_cpar;
    end

    `PRIM_FF_RST(spread_out_request     , spread_request              , rst, clk, '0)
    `PRIM_FF_RST(spread_out_merge_cid   , spread_out_merge_cid_next   , rst, clk, '0)
    `PRIM_FF_RST(spread_out_merge_parity, spread_out_merge_parity_next, rst, clk, '0)

//////////////////////////////////////////
// ???
/////////////////////////////////////////
    always_comb begin
        if(spread_in_request & is_spread_affected) begin
            self_cid_next = spread_in_merge_cid.dst;
        end
        else if(merge_request_any) begin
            self_cid_next = dst_cid;
        end
        else begin
            self_cid_next = self_cid;
        end

        if(syndrome_update) begin
            self_cpar_next = 1'b1;
        end
        else if(spread_in_request & is_spread_affected) begin
            self_cpar_next = spread_in_merge_parity; 
        end
        else if(merge_request_any) begin
            self_cpar_next = self_cpar ^ dst_cpar;
        end
        else begin
            self_cpar_next = self_cpar;
        end
    end

    `PRIM_FF_RST(self_cid , self_cid_next , rst, clk, DEFAULT_CID)
    `PRIM_FF_RST(self_cpar, self_cpar_next, rst, clk, '0)

    `PRIM_FF_EN_RST(syndrome, 1'b1, syndrome_update, rst, clk, '0)
endmodule
