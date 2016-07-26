module SupportN3
  def self.fragment(k)
    k.try(:fragment) || (k.try(:name) || k).to_s.gsub(/.*#/,'')
  end

  def self.step_template(quads)
    value = quads.select{|quad| fragment(quad[1]) == 'stepTemplate'}.flatten[2]
    fragment(value) unless value.nil?
  end

  def self.keep_selectedList(quads)
    quads.select{|quad| fragment(quad[1]) == 'unselectAsset'}.map{|q| fragment(q[2])}.flatten
  end

  def self.check_keep_selected_asset(fr, quads)
    list = keep_selectedList(quads)
    !list.include?(fr)
  end

  def self.step_type(quads)
    names = quads.select{|quad| fragment(quad[1]) == 'stepTypeName'}.flatten
    old_step_type = StepType.where(:name => names[2].to_s, :superceded_by_id => nil).first
    if old_step_type
      step_type =  old_step_type.dup
      step_type.save!
      old_step_type.deprecate_with(step_type)
      return step_type
    end
    return StepType.find_or_create_by(:name => names[2].to_s) unless names.empty?
    return StepType.create(:name => "Rule from #{DateTime.now.to_s}")
  end

  def self.activity_type(quads)
    name = quads.select{|quad| fragment(quad[1]) == 'activityTypeName'}.flatten[2].to_s
    unless name.empty?
      old_activity_type = ActivityType.find_by({ :name => name, :superceded_by_id => nil })
    end
    activity_type = old_activity_type ? old_activity_type.dup : ActivityType.new(:name => name)
    activity_type.save!
    old_activity_type.deprecate_with(activity_type) if old_activity_type
    return activity_type
  end

  def self.parse_string(input, options = {}, step_type)
    options = {
      validate: false,
      canonicalize: false,
    }.merge(options)
    self.parse_rules(RDF::N3::Reader.new(input, options).quads, step_type)
  end

  def self.parse_file(file_path)
    RDF::N3::Reader.open(file_path) do |reader|
      self.load_quads(reader.quads)
    end
  end

  def self.parse_rules(quads, step_type)
    rules = quads.select{|quad| fragment(quad[1])=='implies'}
    rules.each do |k,p,v,g|
      conditions = quads.select{|quad| quad.last === k}
      actions = quads.select{|quad| quad.last === v}

      # Creation of condition groups in the antecedents
      c_groups = {}
      conditions.each do |k,p,v,g|
        fr = fragment(k)
        if c_groups.keys.include?(fr)
          condition_group = c_groups[fr]
        else
          condition_group = ConditionGroup.create(:step_type => step_type, :name => fr, :keep_selected => check_keep_selected_asset(fr, quads))
          c_groups[fr] = condition_group
        end
        if fragment(p) == 'maxCardinality'
          condition_group.update_attributes(:cardinality => fragment(v))
        else
          Condition.create({ :predicate => fragment(p), :object => fragment(v),
          :condition_group_id => condition_group.id})
        end
      end

      actions.each do |k,p,v,g|
        action = fragment(p)
        unless v.literal?
          quads.select{|quad| quad.last == v}.each do |k,p,v,g|
            if c_groups[fragment(k)].nil?
              # Whenever I find a new variable name for an element I have to create a
              # new ConditionGroup for it and collect it. This is because I need a way
              # to remember
              cardinality = nil
              # If it's a variable (like :q, instead of ?q), it will be applied just
              # once for all the step, not for every actioned element
              if k.class.name=='RDF::Query::Variable'
                cardinality=1
              end
              c_groups[fragment(k)] = ConditionGroup.create(:cardinality => cardinality, :name => fragment(k), :keep_selected => check_keep_selected_asset(fragment(k), quads))
            end
            object_condition_group_id = nil
            if v.class.name == 'RDF::Query::Variable'
              if c_groups[fragment(v)].nil?
                c_groups[fragment(v)] = ConditionGroup.create(:cardinality => 1, :name => fragment(v), :keep_selected => check_keep_selected_asset(fragment(v), quads))
              end
              object_condition_group_id = c_groups[fragment(v)].id
            end
            #subject_condition_group_id = c_groups[fragment(k)].nil? ? nil : c_groups[fragment(k)].id
            Action.create({:action_type => action, :predicate => fragment(p),
              :object => fragment(v),
              :step_type_id => step_type.id,
              :subject_condition_group_id => c_groups[fragment(k)].id,
              :object_condition_group_id => object_condition_group_id
            })
          end
        end
      end
    end
  end

  def self.load_quads(quads)
    activity_type = activity_type(quads)
    rules = quads.select{|quad| fragment(quad[1])=='implies'}
    rules.each do |k,p,v,g|
      conditions = quads.select{|quad| quad.last === k}
      actions = quads.select{|quad| quad.last === v}

      step_type = step_type(actions)
      template = step_template(actions)
      unless template.nil?
        step_type.update_attributes(:step_template => template)
      end
      step_type.activity_types << activity_type

      # Creation of condition groups in the antecedents
      c_groups = {}
      conditions.each do |k,p,v,g|
        fr = fragment(k)
        if c_groups.keys.include?(fr)
          condition_group = c_groups[fr]
        else
          condition_group = ConditionGroup.create(:step_type => step_type, :name=> fr, :keep_selected => check_keep_selected_asset(fr, actions))
          c_groups[fr] = condition_group
        end
        if fragment(p) == 'maxCardinality'
          condition_group.update_attributes(:cardinality => fragment(v))
        else
          Condition.create({ :predicate => fragment(p), :object => fragment(v),
          :condition_group_id => condition_group.id})
        end
      end

      actions.each do |k,p,v,g|
        action = fragment(p)
        unless v.literal?
          quads.select{|quad| quad.last == v}.each do |k,p,v,g|
            if c_groups[fragment(k)].nil?
              # Whenever I find a new variable name for an element I have to create a
              # new ConditionGroup for it and collect it. This is because I need a way
              # to remember
              cardinality = nil
              # If it's a variable (like :q, instead of ?q), it will be applied just
              # once for all the step, not for every actioned element
              if k.class.name=='RDF::Query::Variable'
                cardinality=1
              end
              c_groups[fragment(k)] = ConditionGroup.create({:cardinality => cardinality,
                :name => fragment(k), :keep_selected => check_keep_selected_asset(fragment(k), actions)})
            end
            object_condition_group_id = nil
            if v.class.name == 'RDF::Query::Variable'
              if c_groups[fragment(v)].nil?
                c_groups[fragment(v)] = ConditionGroup.create(:cardinality => 1, :name=> fragment(v), :keep_selected => check_keep_selected_asset(fragment(v), actions))
              end
              object_condition_group_id = c_groups[fragment(v)].id
            end
            #subject_condition_group_id = c_groups[fragment(k)].nil? ? nil : c_groups[fragment(k)].id
            Action.create({:action_type => action, :predicate => fragment(p),
              :object => fragment(v),
              :step_type_id => step_type.id,
              :subject_condition_group_id => c_groups[fragment(k)].id,
              :object_condition_group_id => object_condition_group_id
            })
          end
        end
      end
    end
  end
end
