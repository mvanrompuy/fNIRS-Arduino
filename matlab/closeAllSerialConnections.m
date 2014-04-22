function closeAllSerialConnections()
    try
        objs = instrfind
        fclose(objs);
        delete(objs);
        clear objs;
    catch
        % Nothing to close
    end