# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2020, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER(S) AND ANY CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER(S), ANY CONTRIBUTORS, THE
# UNITED STATES GOVERNMENT, OR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF
# THEIR EMPLOYEES, BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************

# start the measure
class CreateSimpleGlazing < OpenStudio::Measure::ModelMeasure
  # define the name that a user will see
  def name
    return "Create_Simple_Glazing"
  end
  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make a choice argument for constructions that are appropriate for windows
    construction_handles = OpenStudio::StringVector.new
    construction_display_names = OpenStudio::StringVector.new

    # putting space types and names into hash
    construction_args = model.getConstructions
    construction_args_hash = {}
    construction_args.each do |construction_arg|
      construction_args_hash[construction_arg.name.to_s] = construction_arg
    end

    # looping through sorted hash of constructions
    construction_args_hash.sort.map do |key, value|
      # only include if construction is a valid fenestration construction
      if value.isFenestration
        construction_handles << value.handle.to_s
        construction_display_names << key
      end
    end

    # todo - replace construction argument with comma separated strings
    # make a choice argument for fixed windows
    construction = OpenStudio::Measure::OSArgument.makeChoiceArgument('construction', construction_handles, construction_display_names, true)
    construction.setDisplayName('Pick a Window Construction From the Model to Replace Existing Window Constructions.')
    args << construction

    # make a bool argument for fixed windows
    change_fixed_windows = OpenStudio::Measure::OSArgument.makeBoolArgument('change_fixed_windows', true)
    change_fixed_windows.setDisplayName('Change Fixed Windows?')
    change_fixed_windows.setDefaultValue(true)
    args << change_fixed_windows

    # make a bool argument for operable windows
    change_operable_windows = OpenStudio::Measure::OSArgument.makeBoolArgument('change_operable_windows', true)
    change_operable_windows.setDisplayName('Change Operable Windows?')
    change_operable_windows.setDefaultValue(true)
    args << change_operable_windows

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    construction = runner.getOptionalWorkspaceObjectChoiceValue('construction', user_arguments, model)
    change_fixed_windows = runner.getBoolArgumentValue('change_fixed_windows', user_arguments)
    change_operable_windows = runner.getBoolArgumentValue('change_operable_windows', user_arguments)

    # check the construction for reasonableness
    if construction.empty?
      handle = runner.getStringArgumentValue('construction', user_arguments)
      if handle.empty?
        runner.registerError('No construction was chosen.')
      else
        runner.registerError("The selected construction with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if !construction.get.to_Construction.empty?
        construction = construction.get.to_Construction.get
      else
        runner.registerError('Script Error - argument not showing up as construction.')
        return false
      end
    end

    # todo - make a new construction and simple glazing instead of pulling in 
    #window_mat = OpenStudio::Model::SimpleGlazing.new(model)
    #construction = OpenStudio::Model::Construction.new(model)
    #construction.setName("New Simple Glazing Construction")
    #construction.insertLayer(0, window_mat)

    # clone construction to get proper area for measure economics, in case it is used elsewhere in the building
    new_object = construction.clone(model)
    if !new_object.to_Construction.empty?
      construction = new_object.to_Construction.get
    end

    # loop through sub surfaces
    starting_exterior_windows_constructions = []
    sub_surfaces_to_change = []
    sub_surfaces = model.getSubSurfaces
    sub_surfaces.each do |sub_surface|
      if (sub_surface.outsideBoundaryCondition == 'Outdoors') && (sub_surface.subSurfaceType == 'FixedWindow') && (change_fixed_windows == true)
        sub_surfaces_to_change << sub_surface
        sub_surface_const = sub_surface.construction
        if !sub_surface_const.empty?
          if starting_exterior_windows_constructions.empty?
            starting_exterior_windows_constructions << sub_surface_const.get.name.to_s
          else
            starting_exterior_windows_constructions << sub_surface_const.get.name.to_s
          end
        end
      elsif (sub_surface.outsideBoundaryCondition == 'Outdoors') && (sub_surface.subSurfaceType == 'OperableWindow') && (change_operable_windows == true)
        sub_surfaces_to_change << sub_surface
        sub_surface_const = sub_surface.construction
        if !sub_surface_const.empty?
          if starting_exterior_windows_constructions.empty?
            starting_exterior_windows_constructions << sub_surface_const.get.name.to_s
          else
            starting_exterior_windows_constructions << sub_surface_const.get.name.to_s
          end
        end
      end
    end

    if (change_fixed_windows == false) && (change_operable_windows == false)
      runner.registerAsNotApplicable('Fixed and operable windows are both set not to change.')
      return true # no need to waste time with the measure if we know it isn't applicable
    elsif sub_surfaces_to_change.empty?
      runner.registerAsNotApplicable('There are no appropriate exterior windows to change in the model.')
      return true # no need to waste time with the measure if we know it isn't applicable
    end

    # report initial condition
    runner.registerInitialCondition("The building had #{starting_exterior_windows_constructions.uniq.size} window constructions: #{starting_exterior_windows_constructions.uniq.sort.join(', ')}.")

    # create array of constructions for sub_surfaces to change, before construction is replaced
    constructions_to_change = []
    sub_surfaces_to_change.each do |sub_surface|
      if !sub_surface.construction.empty?
        constructions_to_change << sub_surface.construction.get
      end
    end

    # loop through construction sets used in the model
    default_construction_sets = model.getDefaultConstructionSets
    default_construction_sets.each do |default_construction_set|
      if default_construction_set.directUseCount > 0
        default_sub_surface_const_set = default_construction_set.defaultExteriorSubSurfaceConstructions
        if !default_sub_surface_const_set.empty?
          starting_construction = default_sub_surface_const_set.get.fixedWindowConstruction

          # creating new default construction set
          new_default_construction_set = default_construction_set.clone(model)
          new_default_construction_set = new_default_construction_set.to_DefaultConstructionSet.get

          # create new sub_surface set
          new_default_sub_surface_const_set = default_sub_surface_const_set.get.clone(model)
          new_default_sub_surface_const_set = new_default_sub_surface_const_set.to_DefaultSubSurfaceConstructions.get

          if change_fixed_windows == true
            # assign selected construction sub_surface set
            new_default_sub_surface_const_set.setFixedWindowConstruction(construction)
          end

          if change_operable_windows == true
            # assign selected construction sub_surface set
            new_default_sub_surface_const_set.setOperableWindowConstruction(construction)
          end

          # link new subset to new set
          new_default_construction_set.setDefaultExteriorSubSurfaceConstructions(new_default_sub_surface_const_set)

          # swap all uses of the old construction set for the new
          construction_set_sources = default_construction_set.sources
          construction_set_sources.each do |construction_set_source|
            building_source = construction_set_source.to_Building
            if !building_source.empty?
              building_source = building_source.get
              building_source.setDefaultConstructionSet(new_default_construction_set)
              next
            end
            # add SpaceType, BuildingStory, and Space if statements
          end
        end
      end
    end

    # loop through appropriate sub surfaces and change where there is a hard assigned construction
    sub_surfaces_to_change.each do |sub_surface|
      if !sub_surface.isConstructionDefaulted
        sub_surface.setConstruction(construction)
      end
    end

    # ip construction area for reporting
    const_area_ip = OpenStudio.convert(OpenStudio::Quantity.new(construction.getNetArea, OpenStudio.createUnit('m^2').get), OpenStudio.createUnit('ft^2').get).get.value

    # get names from constructions to change
    const_names = []
    if !constructions_to_change.empty?
      constructions_to_change.uniq.sort.each do |const_name|
        const_names << const_name.name
      end
    end

    # need to format better. At first I did each do, but seems initial condition only reports the first one.
    runner.registerFinalCondition("#{OpenStudio.toNeatString(const_area_ip, 0, true)} (ft^2) of existing windows of the types: #{const_names.join(', ')} were replaced by new #{construction.name} windows.")

    return true
  end
end

# this allows the measure to be used by the application
CreateSimpleGlazing.new.registerWithApplication
