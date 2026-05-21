function result = runAlgorithmTrial(config)
% runAlgorithmTrial - HATC baseline trial entry point.
    driver = HatcDriver(config);
    result = driver.run();
end
