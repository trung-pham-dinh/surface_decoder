`include "prim.svh"

import common_pkg::*;

module pe #(
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

    , output logic         in_erasure_left
    , output logic         in_erasure_right
    , output logic         in_erasure_top
    , output logic         in_erasure_bot

    , output logic         out_erasure_left
    , output logic         out_erasure_right
    , output logic         out_erasure_top
    , output logic         out_erasure_bot

      // OUT
    , output cid_t         out_cid
    , output logic         cpar

    // Global communication
    , input  pe_state_e    pe_state
    , input  logic         syndrome_update // pulse -> syndrome updated to 1
    , output logic         syndrome


    // Broadcast
    , input  merged_cids_t brdcst_in_merge_ids
    , input  logic         brdcst_in_merge_parity
    , input  logic         brdcst_in_vld

    , output logic         brdcst_out_vld
    , output merged_cids_t brdcst_out_merge_ids
    , output logic         brdcst_out_merge_parity
);
  logic self_cpar;
  cid_t self_cid, self_cid_next;

//////////////////////////////////////////
// Initialize
//////////////////////////////////////////
  `PRIM_FF_EN_RST(syndrome, (1'b1), syndrome_update, rst, clk, '0)

//////////////////////////////////////////
// Connect
//////////////////////////////////////////

//////////////////////////////////////////
// Grow
//////////////////////////////////////////
  logic is_full_grow, is_connected, is_in_cluster;
  logic out_erasure_left_next, out_erasure_right_next, out_erasure_bot_next, out_erasure_top_next;
  logic grow_cond;
  logic out_grow_ps_next;

  always_comb begin
    is_full_grow  = out_erasure_left & out_erasure_right & out_erasure_top & out_erasure_bot; 
    is_connected  = in_erasure_left  | in_erasure_right  | in_erasure_top  | in_erasure_bot;
    is_in_cluster = is_connected | syndrome;

    grow_cond = is_in_cluster & ~is_full_grow;

    out_erasure_left_next  = (grow_cond) ? 1'b1 : out_erasure_left;
    out_erasure_right_next = (grow_cond) ? 1'b1 : out_erasure_right;
    out_erasure_bot_next   = (grow_cond) ? 1'b1 : out_erasure_bot;
    out_erasure_top_next   = (grow_cond) ? 1'b1 : out_erasure_top;

  end
  `PRIM_FF_RST(out_erasure_left , out_erasure_left_next , rst, clk, '0)
  `PRIM_FF_RST(out_erasure_right, out_erasure_right_next, rst, clk, '0)
  `PRIM_FF_RST(out_erasure_bot  , out_erasure_bot_next  , rst, clk, '0)
  `PRIM_FF_RST(out_erasure_top  , out_erasure_top_next  , rst, clk, '0)

//////////////////////////////////////////
// Devoured (being 'eaten': update parity and cluster id)
// or Competitively devoured (multiple clusters try to devour this PE)
//////////////////////////////////////////
  cid_t smallest_lr_cid, smallest_bt_cid, smallest_cid;
  logic brdcst_out_vld_next;
  logic is_no_cid_left,is_no_cid_right,is_no_cid_bot,is_no_cid_top;
  logic merge_parity;
  logic merge_cond;
  logic merge_left,merge_right,merge_bot,merge_top;
  merged_cids_t brdcst_out_merge_ids_next;
  logic brdcst_update;
  logic self_cpar_next;

  always_comb begin
    merge_parity = ^{in_cpar_left, in_cpar_right, in_cpar_bot, in_cpar_top, self_cpar};

    is_no_cid_left  = in_cid_left  == NON_CID;
    is_no_cid_right = in_cid_right == NON_CID;
    is_no_cid_bot   = in_cid_bot   == NON_CID;
    is_no_cid_top   = in_cid_top   == NON_CID;

    brdcst_out_vld_next  = $countones(
      { 
       is_no_cid_left, 
       is_no_cid_right, 
       is_no_cid_bot, 
       is_no_cid_top
      }) != 3'd4; // TODO: should be careful, dont know if countones is synthesizable    
  end

  always_comb begin
    smallest_lr_cid = (in_cid_left     < in_cid_right   ) ? in_cid_left     : in_cid_right;
    smallest_bt_cid = (in_cid_bot      < in_cid_top     ) ? in_cid_bot      : in_cid_top;
    smallest_cid    = (smallest_lr_cid < smallest_bt_cid) ? smallest_lr_cid : smallest_bt_cid;

    brdcst_out_merge_ids_next.target = smallest_cid;
    brdcst_out_merge_ids_next.left   = in_cid_left ;
    brdcst_out_merge_ids_next.right  = in_cid_right;
    brdcst_out_merge_ids_next.bot    = in_cid_bot  ;
    brdcst_out_merge_ids_next.top    = in_cid_top  ;

    merge_left  = (in_erasure_left  & out_erasure_left_next ) && (in_cid_left  != self_cid);
    merge_right = (in_erasure_right & out_erasure_right_next) && (in_cid_right != self_cid);
    merge_bot   = (in_erasure_bot   & out_erasure_bot_next  ) && (in_cid_bot   != self_cid);
    merge_top   = (in_erasure_top   & out_erasure_top_next  ) && (in_cid_top   != self_cid);
    merge_cond  = merge_left | merge_right | merge_bot | merge_top;
    
    brdcst_update = brdcst_in_vld 
                  & (
                       self_cid == brdcst_in_merge_ids.left
                    || self_cid == brdcst_in_merge_ids.right
                    || self_cid == brdcst_in_merge_ids.bot
                    || self_cid == brdcst_in_merge_ids.top
                  );

    if(syndrome_update) begin
      self_cid_next = DEFAULT_CID;
    end 
    else if (brdcst_update) begin
      self_cid_next = brdcst_in_merge_ids.target;
    end
    else if (merge_cond) begin
      self_cid_next = smallest_cid;
    end
    else begin
      self_cid_next = self_cid;
    end

    if(syndrome_update) begin
      self_cpar_next = 1'b1;
    end
    else if (brdcst_update) begin
      self_cpar_next = brdcst_in_merge_parity;
    end
    else if (merge_cond) begin
      self_cpar_next = merge_parity;
    end
    else begin
      self_cpar_next = self_cpar;
    end
  end
  
  `PRIM_FF_RST(brdcst_out_vld         , brdcst_out_vld_next         , rst, clk, '0)
  `PRIM_FF_RST(brdcst_out_merge_ids   , brdcst_out_merge_ids_next   , rst, clk, '0)
  `PRIM_FF_RST(self_cid, self_cid_next, rst, clk, NON_CID) // TODO: '0 must not be the default, because it is a valid ID
  `PRIM_FF_RST(self_cpar, self_cpar_next, rst, clk, '0)

  assign brdcst_out_merge_parity = self_cpar;
endmodule
