function train_id_net_vgg16(varargin)
% -------------------------------------------------------------------------
% Part 4.1: prepare the data
% -------------------------------------------------------------------------

imdb = load('./dataset/MSCOCO-prepare/url_data.mat');
imdb = imdb.imdb;
load('./dataset/MSCOCO-prepare/coco_word2.mat');
%sort row
[imdb.images.label2,index] = sort(imdb.images.label2);
wordcnn = wordcnn(:,index);
imdb.charcnn = wordcnn; 
%imdb.charmean = mean(imdb.charcnn(:,:,:,imdb.images.set==1),4);
% -------------------------------------------------------------------------
% Part 4.2: initialize a CNN architecture
% -------------------------------------------------------------------------
net = coco_word2_pool_no_w2v();
net.conserveMemory = true;
im_mean = imdb.rgbMean;
net.meta.normalization.averageImage = im_mean;
%net.meta.normalization.charmean = imdb.charmean;
% -------------------------------------------------------------------------
% Part 4.3: train and evaluate the CNN

% -------------------------------------------------------------------------
opts.train.averageImage = net.meta.normalization.averageImage;
opts.train.batchSize = 32;
opts.train.continue = true;
opts.train.gpus = 2;
opts.train.prefetch = false ;
opts.train.nesterovUpdate = true ;
opts.train.expDir = './data/res52_coco_batch32_pool_shift_both_drop0.5_no_w2v';
opts.train.derOutputs = {'objective_img',1,'objective_txt',1} ;
%opts.train.gamma = 0.9;
opts.train.momentum = 0.9;
%opts.train.constraint = 100;
opts.train.learningRate = [0.1*ones(1,90)] ;
opts.train.weightDecay = 0.0001;
opts.train.numEpochs = numel(opts.train.learningRate) ;
[opts, ~] = vl_argparse(opts.train, varargin) ;
% Call training function in MatConvNet
[net,info] = cnn_train_dag(net, imdb, @getBatch,opts) ;

% --------------------------------------------------------------------
function inputs = getBatch(imdb,batch,opts)
% --------------------------------------------------------------------
%-- img data
im_url = imdb.images.data(batch) ;
im = vl_imreadjpeg(im_url,'Pack','Resize',[224,224],'Flip',...
    'CropLocation','random','CropSize',[0.8,1],...
    'Interpolation', 'bicubic','NumThreads',16,... %'Brightness', double(0.1*imdb.rgbCovariance),...
    'SubtractAverage',imdb.rgbMean,...
    'CropAnisotropy',[3/4,4/3]);
oim = im{1}; %bsxfun(@minus,im{1},opts.averageImage);
label_img =  imdb.images.label(batch);

%-- txt data
batchsize = numel(batch);
txt_batch = zeros(1,batchsize);
for i=1:batchsize
  txt_batch(i) = rand_same_class_coco(imdb,label_img(i));  % train txt range 1~68126
end
%label_txt =  imdb.images.label2(txt_batch);
label_txt = label_img;
txt = single(imdb.charcnn(:,txt_batch));
txtinput = zeros(1,32,29972,batchsize,'single');
for i=1:batchsize
    len = sum(txt(:,i)>0);
    location = randi(33-len);
    for j=1:len
        v = txt(j,i);
       txtinput(1,location,v,i)=1;
       location = location+1;
    end
end
txtinput = gpuArray(txtinput);
%}
%--
inputs = {'data',gpuArray(oim),'data2',txtinput,'label_img',label_img,'label_txt',label_txt};
