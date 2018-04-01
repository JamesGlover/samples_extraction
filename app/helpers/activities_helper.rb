module ActivitiesHelper

  def asset_types_for(assets_grouped, step_type, &block)
    created_condition_groups = []
    asset_types = []
    @assets_grouped.each do |fact_group, assets|
      fake_asset = Struct.new(:facts).new(fact_group)
      cgs=step_type.condition_groups.select do |c|
        c.compatible_with?(fake_asset)
      end
      created_condition_groups << cgs
      yield(fact_group, assets, cgs)
    end
    remaining_condition_groups =  step_type.condition_groups - created_condition_groups.flatten
    klass = Struct.new(:predicate, :object, :object_asset_id, :to_add_by, :to_remove_by)
    remaining_condition_groups.each do |remaining|
      conditions_to_facts = remaining.conditions.map do |c|
        klass.new(c.predicate, c.object, nil, nil, nil)
      end
      yield(conditions_to_facts, [], [remaining])
    end
  end

  def step_types_data
    @step_types.map do |st|
    {
      createStepUrl: activity_steps_path(@activity),
      stepType: st,
      name: st.name
    }
    end
  end

  def step_types_data_for_step_types(activity, step_types)
    step_types.map do |st|
    {
      createStepUrl: activity_steps_path(activity),
      stepType: st,
      name: st.name
    }
    end
  end


  def step_types_for_asset_groups_data(activity, asset_group)
    step_types = activity.step_types_for(asset_group.assets)
    {
      updateUrl: activity_step_types_path(activity),
      stepTypesData: step_types_data_for_step_types(activity, step_types),
      stepTypesTemplatesData: step_type_templates_data_for_step_types(activity, step_types)
    }
  end

  def step_types_control_data(activity)
    activity.owned_asset_groups.reduce({}) do |memo, asset_group|
      data_for_step_types = step_types_for_asset_groups_data(activity, asset_group)
      memo[asset_group.id] = data_for_step_types
      memo
    end
  end

  #updateUrl: activity_step_types_path(@activity),
  #stepTypesData: step_types_data,
  #stepTypesTemplatesData: step_type_templates_data


  def steps_data
    @steps.reverse.map do |step|
      {
        activity: step.activity,
        asset_group: step.asset_group,
        step_type: step.step_type,
        operations: step.operations
      }.merge(step.attributes)
    end
  end

  def asset_data(asset)
    {barcode: asset.barcode, uuid: asset.uuid, facts: asset.facts}
  end

  def asset_group_data(activity, asset_group)
    {
      id: asset_group.id,
      selected: (activity.asset_group==asset_group),
      updateUrl: activity_asset_group_url(activity, asset_group),
      condition_group_name: asset_group.condition_group_name,
      assets: asset_group.assets.map{|asset| asset_data(asset)}
    }
  end

  def asset_groups_data(activity)
    activity.owned_asset_groups.reduce({}) do |memo, asset_group|
      data_for_step_types = asset_group_data(activity, asset_group)
      memo[asset_group.id] = data_for_step_types
      memo
    end
  end


  def step_type_templates_data
    @step_types.select{|s| s.step_template }.map do |st|
      {
        createStepUrl: activity_steps_path(@activity),
        stepType: st,
        name: st.name,
        id: "step-type-id-#{ rand(9999).to_s }-#{ st.id }"
      }
    end
  end

  def step_type_templates_data_for_step_types(activity, step_types)
    step_types.select{|s| s.step_template }.map do |st|
      {
        createStepUrl: activity_steps_path(activity),
        stepType: st,
        name: st.name,
        id: "step-type-id-#{ rand(9999).to_s }-#{ st.id }"
      }
    end
  end


end
