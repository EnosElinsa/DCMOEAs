function result = runAlgorithmTrial(config)
% runAlgorithmTrial - CRDCMO baseline trial entry point.
    driver = CrdcmoDriver(config);
    result = driver.run();
end
