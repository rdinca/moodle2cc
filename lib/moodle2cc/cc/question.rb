module Moodle2CC::CC
  class Question
    include CCHelper

    META_ATTRIBUTES = [:question_type, :points_possible]
    QUESTION_TYPE_MAP = {
        'calculated' =>  'calculated_question',
        'description' => 'text_only_question',
        'essay' => 'essay_question',
        'match' => 'matching_question',
        'multianswer' => 'multiple_answers_question',
        'multichoice' => 'multiple_choice_question',
        'shortanswer' => 'short_answer_question',
        'numerical' => 'numerical_question',
        'truefalse' => 'true_false_question',
      }

    attr_accessor :id, :title, :material, :general_feedback, :answer_tolerance,
      :formulas, :formula_decimal_places, :vars, :var_sets, :identifier, *META_ATTRIBUTES

    def initialize(question_instance)
      question = question_instance.question
      @id = question.id
      @title = question.name
      @question_type = QUESTION_TYPE_MAP[question.type]
      @points_possible = question_instance.grade
      @material = question.text.gsub(/\{(.*?)\}/, '[\1]')
      @general_feedback = question.general_feedback
      calculation = question.calculations.first
      if calculation
        @answer_tolerance = calculation.tolerance
        @formula_decimal_places = calculation.correct_answer_format == 1 ? calculation.correct_answer_length : 0
        @formulas = question.answers.map { |a| a.text.gsub(/[\{\}\s]/, '') }
        @vars = calculation.dataset_definitions.map do |ds_def|
          name = ds_def.name
          type, min, max, scale = ds_def.options.split(':')
          {:name => name, :min => min, :max => max, :scale => scale}
        end
        @var_sets = []
        calculation.dataset_definitions.each do |ds_def|
          ds_def.dataset_items.sort_by(&:number).each_with_index do |ds_item, index|
            var_set = @var_sets[index] || {}
            vars = var_set[:vars] || {}
            vars[ds_def.name] = ds_item.value
            var_set[:vars] = vars
            @var_sets[index] = var_set
          end
        end
        @var_sets.map do |var_set|
          answer = 0
          var_set[:vars].each do |k, v|
            answer += v
          end
          var_set[:answer] = answer
        end
      end
      @identifier = create_key(@id, 'question_')
    end

    def create_item_xml(section_node)
      section_node.item(:title => @title, :ident => @identifier) do |item_node|
        item_node.itemmetadata do |meta_node|
          meta_node.qtimetadata do |qtime_node|
            META_ATTRIBUTES.each do |attr|
              value = send(attr)
              if value
                qtime_node.qtimetadatafield do |field_node|
                  field_node.fieldlabel attr.to_s
                  field_node.fieldentry value
                end
              end
            end
          end
        end

        item_node.presentation do |presentation_node|
          presentation_node.material do |material_node|
            material_node.mattext(@material, :texttype => 'text/html')
          end
          create_response_str(presentation_node)
        end

        item_node.resprocessing do |processing_node|
          processing_node.outcomes do |outcomes_node|
            outcomes_node.decvar(:maxvalue => '100', :minvalue => '0', :varname => 'SCORE', :vartype => 'Decimal')
          end
          if @general_feedback
            processing_node.respcondition(:continue => 'Yes') do |condition_node|
              condition_node.conditionvar do |var_node|
                var_node.other
              end
              condition_node.displayfeedback(:feedbacktype => 'Response', :linkrefid => 'general_fb')
            end
          end
          create_response_conditions(processing_node)
        end

        # Feeback
        if @general_feedback
          item_node.itemfeedback(:ident => 'general_fb') do |fb_node|
            fb_node.flow_mat do |flow_node|
              flow_node.material do |material_node|
                material_node.mattext(@general_feedback, :texttype => 'text/plain')
              end
            end
          end
        end

        create_additional_nodes(item_node)
      end
    end

    def create_response_str(presentation_node)
      case @question_type
      when 'calculated_question'
        presentation_node.response_str(:rcardinality => 'Single', :ident => 'response1') do |response_node|
          response_node.render_fib(:fibtype => 'Decimal') do |render_node|
            render_node.response_label(:ident => 'answer1')
          end
        end
      end
    end

    def create_response_conditions(processing_node)
      case @question_type
      when 'calculated_question'
        processing_node.respcondition(:title => 'correct') do |condition|
          condition.conditionvar do |var_node|
            var_node.other
          end
          condition.setvar('100', :varname => 'SCORE', :action => 'Set')
        end
        processing_node.respcondition(:title => 'incorrect') do |condition|
          condition.conditionvar do |var_node|
            var_node.other
          end
          condition.setvar('0', :varname => 'SCORE', :action => 'Set')
        end
      end
    end

    def create_additional_nodes(item_node)
      case @question_type
      when 'calculated_question'
        item_node.itemproc_extension do |extension_node|
          extension_node.calculated do |calculated_node|
            calculated_node.answer_tolerance @answer_tolerance
            calculated_node.formulas(:decimal_places => @formula_decimal_places) do |formulas_node|
              @formulas.each do |formula|
                formulas_node.formula formula
              end
            end
            calculated_node.vars do |vars_node|
              @vars.each do |var|
                vars_node.var(:name => var[:name], :scale => var[:scale]) do |var_node|
                  var_node.min var[:min]
                  var_node.max var[:max]
                end
              end
            end
            calculated_node.var_sets do |var_sets_node|
              @var_sets.each do |var_set|
                ident = var_set[:vars].sort.map { |k,v| v.to_s.split('.').join }.flatten.join
                var_sets_node.var_set(:ident => ident) do |var_set_node|
                  var_set[:vars].each do |k, v|
                    var_set_node.var(v, :name => k)
                  end
                  var_set_node.answer var_set[:answer]
                end
              end
            end
          end
        end
      end
    end
  end
end
