function TumorDetectionGUI_4Panel
    % =========================================================
    
    % =========================================================

    % --- 1. MAIN FIGURE SETUP ---
    hFig = figure('Name', 'Brain Tumor Analysis System', ...
        'NumberTitle', 'off', ...
        'Position', [100, 100, 1000, 700], ... 
        'Color', [0.94 0.94 0.94], ...
        'MenuBar', 'none', ...
        'Resize', 'off');
    

    % --- 2. CONTROL PANEL (Left Side) ---
    hPanel = uipanel('Parent', hFig, ...
        'Title', 'Control Center', ...
        'FontSize', 12, ...
        'Position', [0.01 0.1 0.20 0.85]);

    % Buttons
    uicontrol('Parent', hPanel, 'Style', 'pushbutton', 'String', '1. LOAD MRI', ...
        'FontSize', 11, 'Position', [20, 480, 160, 40], ...
        'BackgroundColor', [0.2, 0.6, 0.8], 'ForegroundColor', 'white', ...
        'Callback', @LoadImageCallback);

    uicontrol('Parent', hPanel, 'Style', 'pushbutton', 'String', '2. ANALYZE', ...
        'FontSize', 11, 'Position', [20, 420, 160, 40], ...
        'BackgroundColor', [0.8, 0.3, 0.3], 'ForegroundColor', 'white', ...
        'Callback', @DetectCallback);

    uicontrol('Parent', hPanel, 'Style', 'pushbutton', 'String', '3. RESET', ...
        'FontSize', 11, 'Position', [20, 360, 160, 40], ...
        'Callback', @ResetCallback);

    % Status Text
    hStatus = uicontrol('Parent', hPanel, 'Style', 'text', ...
        'String', 'Status: Ready to load...', ...
        'FontSize', 10, 'HorizontalAlignment', 'left', ...
        'Position', [10, 50, 180, 250]);

    % --- 3. 4-PANEL GRID LAYOUT (2x2) ---
    
    % Panel 1: Top Left
    hAx1 = axes('Parent', hFig, 'Position', [0.25, 0.55, 0.32, 0.38]);
    title(hAx1, '(a) Original MRI'); axis(hAx1, 'off');

    % Panel 2: Top Right
    hAx2 = axes('Parent', hFig, 'Position', [0.62, 0.55, 0.32, 0.38]);
    title(hAx2, '(b) Binary Threshold'); axis(hAx2, 'off');

    % Panel 3: Bottom Left
    hAx3 = axes('Parent', hFig, 'Position', [0.25, 0.08, 0.32, 0.38]);
    title(hAx3, '(c) Cleaned Segments'); axis(hAx3, 'off');

    % Panel 4: Bottom Right
    hAx4 = axes('Parent', hFig, 'Position', [0.62, 0.08, 0.32, 0.38]);
    title(hAx4, '(d) Final Detection'); axis(hAx4, 'off');

    % Data Storage
    rawImage = [];

    % =========================================================
    % LOGIC & CALLBACKS
    % =========================================================
    function LoadImageCallback(~, ~)
        [filename, pathname] = uigetfile({'*.jpg;*.jpeg;*.png;*.bmp;*.tif', 'Image Files'}, 'Select MRI');
        
        if isequal(filename, 0)
            return; 
        end
        
        fullPath = fullfile(pathname, filename);
        rawImage = imread(fullPath);
        
        % Ensure Grayscale
        if size(rawImage, 3) == 3
            displayImg = rgb2gray(rawImage);
        else
            displayImg = rawImage;
        end
        
        imshow(displayImg, 'Parent', hAx1);
        title(hAx1, '(a) Original MRI');
        
        % Clear others
        cla(hAx2); cla(hAx3); cla(hAx4);
        set(hStatus, 'String', 'Image Loaded.');
    end

    function DetectCallback(~, ~)
        if isempty(rawImage)
            msgbox('Please load an image first.', 'Error'); return;
        end
        
        set(hStatus, 'String', 'Processing...'); pause(0.1);
        
        try
            % --- PRE-PROCESSING ---
            if size(rawImage, 3) == 3
                grayImg = rgb2gray(rawImage);
            else
                grayImg = rawImage;
            end
            grayImg = imresize(grayImg, [256, 256]);
            
            % --- HIDDEN STEP 1: SKULL STRIPPING ---
            % Logic is calculated but NOT displayed
            lvl = graythresh(grayImg);
            headMask = imbinarize(grayImg, lvl);
            headMask = imfill(headMask, 'holes');
            se_skull = strel('disk', 10);
            brainMask = imerode(headMask, se_skull);
            
            skullStripped = grayImg;
            skullStripped(~brainMask) = 0;
            
            % --- HIDDEN STEP 2: ENHANCEMENT ---
            % Logic is calculated but NOT displayed
            denoised = medfilt2(skullStripped, [3 3]);
            enhanced = imadjust(denoised);
            
            % --- VISIBLE STEP 3: THRESHOLDING ---
            % We use 'enhanced' here, even though we didn't show it
            maxVal = max(enhanced(:));
            if maxVal == 0
                threshVal = 0;
            else
                threshVal = 0.65 * double(maxVal); 
            end
            
            binaryMask = enhanced > threshVal;
            
            % Plot (b)
            imshow(binaryMask, 'Parent', hAx2);
            title(hAx2, '(b) Binary Threshold');
            
            % --- VISIBLE STEP 4: CLEANUP ---
            cleanedMask = bwareaopen(binaryMask, 80);
            cleanedMask = imclose(cleanedMask, strel('disk', 2));
            
            % Plot (c)
            imshow(cleanedMask, 'Parent', hAx3);
            title(hAx3, '(c) Cleaned Segments');
            
            % --- VISIBLE STEP 5: FINAL RESULT ---
            tumorArea = sum(cleanedMask(:));
            
            if tumorArea > 100
                % Tumor Found - Show Thermal View
                finalRGB = ind2rgb(grayImg, jet(256));
                
                imshow(finalRGB, 'Parent', hAx4);
                title(hAx4, '(d) Tumor Detected (Thermal View)');
                
                msg = sprintf('DIAGNOSIS: TUMOR DETECTED\n\nArea: %d pixels', tumorArea);
                set(hStatus, 'String', msg, 'ForegroundColor', 'red');
                msgbox('Tumor Detected!', 'Analysis Complete');
            else
                % Healthy
                imshow(grayImg, 'Parent', hAx4);
                title(hAx4, '(d) Normal Brain');
                
                msg = sprintf('DIAGNOSIS: NORMAL');
                set(hStatus, 'String', msg, 'ForegroundColor', 'blue');
                msgbox('No Tumor Detected.', 'Analysis Complete');
            end
            
        catch ME
            errordlg(ME.message);
        end
    end

    function ResetCallback(~, ~)
        rawImage = [];
        cla(hAx1); cla(hAx2); cla(hAx3); cla(hAx4);
        set(hStatus, 'String', 'Status: Ready', 'ForegroundColor', 'black');
        title(hAx1, '(a) Original MRI');
        title(hAx2, '(b) Binary Threshold');
        title(hAx3, '(c) Cleaned Segments');
        title(hAx4, '(d) Final Detection');
    end
end