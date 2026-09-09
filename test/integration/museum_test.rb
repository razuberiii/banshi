require_relative '../domain_helpers'

class MuseumTest < ActionDispatch::IntegrationTest
  include DomainHelpers
  setup do
    Rack::Attack.cache.store.clear
    @group=domain_group
    @person=domain_transporter
    @entry=domain_entry(group:@group,transporter:@person,title:'会走路的最终版',safety_level:'GREEN',visibility:'public')
    @message=domain_message(group:@group,transporter:@person,content:@entry.content,at:1.hour.ago)
    OccurrenceRecorder.call(entry:@entry,message:@message)
    @user=domain_user
  end
  def login(user=@user)
    post login_path,params:{email:user.email,password:'Domain-tests-2026!'}
    assert_response :redirect
  end

  test 'public museum routes render database records and never external identities' do
    [root_path,entries_path,entry_path(@entry),groups_path,group_path(@group),transporters_path,transporter_path(@person),rankings_path,trials_path,timeline_path,hot_path,classics_path,revivals_path,login_path,signup_path,profile_path(@user)].each do |path|
      get path
      assert_response :success,"failed #{path}: #{response.body.first(200)}"
      assert_select 'main'
      refute_includes response.body,@group.external_id
      refute_includes response.body,@person.external_id
      refute_includes response.body,@user.email
    end
  end

  test 'search filters SID title dates tags group and paginates' do
    get search_path,params:{q:@entry.sid};assert_response :success;assert_select 'a',text:@entry.title
    get entries_path,params:{q:'不会存在的内容'};assert_response :success;assert_select '.entry-card',count:0
    get entries_path,params:{from:'bad-date'};assert_response :success;assert_select '.entry-card',count:0
    get entries_path,params:{group:@group.slug,level:'ARCHIVED'};assert_response :success;assert_includes response.body,@entry.sid
  end

  test 'forward pages preserve nested text image order and escape user supplied content' do
    content=domain_content(kind:'forward')
    asset=Asset.create!(sha256:SecureRandom.hex(32),storage_key:SecureRandom.hex(12),content_type:'image/png',byte_size:10)
    Attachment.create!(content:content,asset:asset,position:0)
    content.update!(metadata:{'forward_tree'=>[{'segments'=>[{'type'=>'text','text'=>'<script>private data</script>'},
      {'type'=>'forward','nodes'=>[{'segments'=>[{'type'=>'text','text'=>'里面的一层'},{'type'=>'image','attachment_position'=>0}]}]}]}]})
    entry=domain_entry(content:content,safety_level:'GREEN',visibility:'public')
    get entry_path(entry)
    assert_response :success
    assert_select '.forward-node .forward-node',count:1
    assert_select '.forward-node img[src=?]',media_path(asset),count:1
    assert_select 'script',text:'private data',count:0
    assert_includes response.body,'&lt;script&gt;private data&lt;/script&gt;'
  end

  test 'hidden entries and private associations never appear on public pages' do
    stats_group=domain_group(visibility:'statistics',public_name:'只可公开统计的秘密群馆')
    secret_group=domain_group(visibility:'hidden')
    private_entry=domain_entry(group:secret_group,title:'不能泄露的标题',safety_level:'GREEN',visibility:'public')
    [stats_group,secret_group].each do |group|
      message=domain_message(group:group,content:@entry.content)
      OccurrenceRecorder.call(entry:@entry,message:message)
    end
    get entry_path(private_entry);assert_response :not_found
    get entry_path(@entry);assert_response :success;refute_includes response.body,stats_group.public_name;refute_includes response.body,secret_group.public_name
    get timeline_path;assert_response :success;refute_includes response.body,stats_group.public_name
    get group_path(stats_group);assert_response :success;assert_includes response.body,'只公开统计';refute_includes response.body,@entry.title
    get group_path(secret_group);assert_response :not_found
  end

  test 'one account can toggle each entertainment rating and favorite' do
    post rate_entry_path(@entry),params:{reaction:'💩'};assert_redirected_to login_path
    login
    assert_difference('WebRating.count',1) { post rate_entry_path(@entry),params:{reaction:'💩'} }
    assert_difference('WebRating.count',1) { post rate_entry_path(@entry),params:{reaction:'😂'} }
    assert_difference('WebRating.count',-1) { post rate_entry_path(@entry),params:{reaction:'💩'} }
    assert_no_difference('WebRating.count') { post rate_entry_path(@entry),params:{reaction:'arbitrary'} };assert_response :unprocessable_entity
    assert_difference('Favorite.count',1) { post favorite_entry_path(@entry) }
    get profile_path(@user);assert_includes response.body,@entry.title
    other=domain_user;login(other);get profile_path(@user);refute_includes response.body,@entry.title
  end

  test 'group management requires membership and cannot change global safety' do
    login
    get edit_group_path(@group);assert_response :forbidden
    patch group_path(@group),params:{group:{daily_limit:99}};assert_response :forbidden
    GroupManagement.create!(group:@group,user:@user,verified_role:'admin',verified_at:Time.current)
    get edit_group_path(@group);assert_response :success
    patch group_path(@group),params:{group:{trial_preference:'OPT_OUT',daily_limit:2,accepted_tags:['','NSFW'],safety_default_level:'GREEN'}}
    assert_redirected_to group_path(@group)
    assert_equal 2,@group.reload.daily_limit
    assert_equal ['NSFW'],@group.accepted_tags
    assert_equal 'RED',AppConfig.safety.default_level
  end

  test 'report submission is persisted and urgent privacy hides the entry' do
    login
    get new_entry_report_path(@entry);assert_response :success
    assert_difference('Report.count',1) { post entry_reports_path(@entry),params:{report:{reason:'privacy',details:'本人内容请求处理'}} }
    assert_redirected_to profile_path(@user)
    assert_equal 'RED',@entry.reload.safety_level
    get entry_path(@entry);assert_response :not_found
    get profile_path(@user);assert_response :success;assert_includes response.body,'举报'
  end

  test 'normal signup cannot grant curator rights and login validates passwords' do
    post signup_path,params:{user:{email:'new-reader@example.test',display_name:'新读者',password:'long-password-2026!',password_confirmation:'long-password-2026!',site_role:'curator'}}
    assert_response :redirect
    assert_equal 'member',User.find_by!(email:'new-reader@example.test').site_role
    delete logout_path
    post login_path,params:{email:@user.email,password:'incorrect'};assert_response :unprocessable_entity
    post signup_path,params:{user:{email:'invalid',display_name:'',password:'short'}};assert_response :unprocessable_entity
  end

  test 'curation and simulator are privileged and flags are enforced' do
    get demo_path;assert_redirected_to login_path
    login
    get demo_path;assert_response :forbidden
    get curation_path;assert_response :forbidden
    get '/health/details';assert_response :forbidden
    AppConfig.with(features:{public_groups:false,web_rating:false},demo:{enabled:false}) do
      get groups_path;assert_response :not_found
      post rate_entry_path(@entry),params:{reaction:'💩'};assert_response :not_found
      post demo_login_path;assert_response :not_found
    end
  end

  test 'curator can explicitly resume reviewed content through the museum curation page' do
    @entry.update!(distribution_paused:true)
    login
    post resume_distribution_path(@entry),params:{reason:'不能越权'}
    assert_response :forbidden
    assert @entry.reload.distribution_paused
    login(domain_user(site_role:'curator'))
    get curation_path,params:{q:@entry.sid}
    assert_response :success
    assert_select 'form[action=?]',resume_distribution_path(@entry),count:1
    post resume_distribution_path(@entry),params:{reason:'逐项复核完成'}
    assert_redirected_to curation_path(q:@entry.sid)
    refute @entry.reload.distribution_paused
  end

  test 'claims are scoped to web identity and displayed only once' do
    login
    post claims_path;assert_response :created
    token=response.body[/CLAIM-[A-Z0-9]{8}/]
    assert token
    claim=@user.claim_tokens.last
    refute_equal token,claim.token_digest
    get claim_path(claim);assert_response :success;refute_includes response.body,token
    other=domain_user;login(other);get claim_path(claim);assert_response :not_found
  end
end
