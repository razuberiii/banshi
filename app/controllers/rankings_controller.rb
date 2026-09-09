class RankingsController < ApplicationController
  BOARDS={'fastest'=>'本周传播最快','natural'=>'自然搬运最多','cross_group'=>'自然跨群最多','longevity'=>'最长寿馆藏','revivals'=>'复活最多','new_classics'=>'本周新晋经典','transporters'=>'搬运员榜','groups'=>'群出土榜','trial_groups'=>'群试吃员榜','bad'=>'烂屎榜'}.freeze
  def index
    @board=BOARDS.key?(params[:board]) ? params[:board] : 'natural'
    @snapshot=LeaderboardSnapshot.find_by(board:@board)
    source=case @board
    when 'transporters' then Transporter.public_profiles
    when 'groups','trial_groups' then AppConfig.features.public_groups ? Group.listed : Group.none
    else ShitEntry.publicly_visible
    end
    rows=@snapshot&.rows || []
    records=source.where(id:rows.map { |r|r['id'] }).index_by(&:id)
    @rows=rows.filter_map { |r|records[r['id'].to_i] ? [records[r['id'].to_i],r['value']] : nil }
  end
end
