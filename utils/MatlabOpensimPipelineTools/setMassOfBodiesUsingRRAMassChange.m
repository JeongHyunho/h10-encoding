function osimModel_rraMassChanges = setMassOfBodiesUsingRRAMassChange(osimModel, massChange)
    currTotalMass = getMassOfModel(osimModel);
    suggestedNewTotalMass = currTotalMass + massChange;
    massScaleFactor = suggestedNewTotalMass/currTotalMass;
    
    allBodies = osimModel.getBodySet();
    for i = 0:allBodies.getSize()-1
        currBodyMass = allBodies.get(i).getMass();
        newBodyMass = currBodyMass*massScaleFactor;
        allBodies.get(i).setMass(newBodyMass);
    end
    osimModel_rraMassChanges = osimModel;
end


function totalMass = getMassOfModel(osimModel)
    totalMass = 0;
    allBodies = osimModel.getBodySet();
    for i=0:allBodies.getSize()-1
        curBody = allBodies.get(i);
        totalMass = totalMass + curBody.getMass();
    end
end
