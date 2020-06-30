# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class CreateAndReportModelObjects < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'create and report model objects'
  end

  # human readable description
  def description
    return 'Test measure to see if various objects and be created and returned in the same order'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'For testing purposes only'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # report initial condition of model
    runner.registerInitialCondition("The building started with #{model.getSpaces.size} spaces.")

    # add a new spaces to the model
    for i in 1..10 do
      new_space = OpenStudio::Model::Space.new(model)

      # echo the new space's name back to the user
      runner.registerInfo("#{new_space.name} was added.")
    end

    # loop through spaces and see how they are returned
    model.getSpaces.each do |space|
      # echo the new space's name back to the user
      runner.registerInfo("#{space.name} is in the model.")
    end

    # report final condition of model
    runner.registerFinalCondition("The building finished with #{model.getSpaces.size} spaces.")

    return true
  end
end

# register the measure to be used by the application
CreateAndReportModelObjects.new.registerWithApplication
