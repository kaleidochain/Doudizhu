/****************************************************************************
Copyright (c) 2015-2016 Chukong Technologies Inc.
Copyright (c) 2017-2018 Xiamen Yaji Software Co., Ltd.
 
http://www.cocos2d-x.org

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
****************************************************************************/
package org.cocos2dx.javascript;

import org.cocos2dx.lib.Cocos2dxActivity;
import org.cocos2dx.lib.Cocos2dxGLSurfaceView;

import android.app.AlertDialog;
import android.content.ClipboardManager;
import android.net.Uri;
import android.os.Bundle;
import org.cocos2dx.javascript.SDKWrapper;
import io.kaleidochain.gengine.Gengine;
import com.cocos.analytics.CAAgent;

import android.content.Context;
import android.content.Intent;
import android.content.res.Configuration;
import android.os.Environment;
import android.util.Log;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.io.FileOutputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.math.BigInteger;
import java.security.MessageDigest;

import io.kaleidochain.doudizhu.R;

public class AppActivity extends Cocos2dxActivity {

    private static AppActivity app = null;
    private static final String SEPARATOR = File.separator;//路径分隔符
    private static final String TAG = "AppActivity";
    /**
     * 计算指定文件的MD5
     * @param filePath 文件路径
     * @return 文件内容MD5
     */
    public static String getFileMD5(String filePath) {
        File file = new File(filePath);
        if (!file.isFile()) {
            return null;
        }
        MessageDigest digest = null;
        FileInputStream in = null;
        byte buffer[] = new byte[1024];
        int len;
        try {
            digest = MessageDigest.getInstance("MD5");
            in = new FileInputStream(file);
            while ((len = in.read(buffer, 0, 1024)) != -1) {
                digest.update(buffer, 0, len);
            }
            in.close();
        } catch (Exception e) {
            e.printStackTrace();
            return null;
        }
        BigInteger bigInt = new BigInteger(1, digest.digest());
        return bigInt.toString(16);
    }
    /**
     * 计算指定流的MD5
     * @param inputStream 流对象
     * @return 流内容MD5
     */
    public static String getStreamMD5(InputStream inputStream) {
        MessageDigest digest = null;
        byte buffer[] = new byte[1024];
        int len;
        try {
            digest = MessageDigest.getInstance("MD5");
            while ((len = inputStream.read(buffer)) != -1) {
                digest.update(buffer, 0, len);
            }
            inputStream.close();
        } catch (Exception e) {
            e.printStackTrace();
            return null;
        }
        BigInteger bigInt = new BigInteger(1, digest.digest());
        return bigInt.toString(16);
    }
    /**
     * 判断res/raw中的文件与目标文件是否相同
     * @param context 上下文
     * @param id 资源ID
     * @param fileName 文件名
     * @param storagePath 目标文件夹的路径
     */
    public static boolean isSameFile(Context context, int id, String fileName, String storagePath) {
        String filePath = storagePath + SEPARATOR + fileName;
        InputStream inputStream = context.getResources().openRawResource(id);
        File file = new File(filePath);
        String srcMD5 = getStreamMD5(inputStream);
        String dstMD5 = getFileMD5(filePath);
        Log.d(TAG, "srcMD5: " + srcMD5);
        Log.d(TAG, "dstMD5: " + dstMD5 + ", dstPath: " + filePath);
        return srcMD5.equals(dstMD5);
    }
    /**
     * 复制res/raw中的文件到指定目录
     * @param context 上下文
     * @param id 资源ID
     * @param fileName 文件名
     * @param storagePath 目标文件夹的路径
     */
    public static void copyFilesFromRaw(Context context, int id, String fileName, String storagePath) {
        InputStream inputStream = context.getResources().openRawResource(id);
        File file = new File(storagePath);
        if (!file.exists()) {//如果文件夹不存在，则创建新的文件夹
            file.mkdirs();
        }
        readInputStream(storagePath + SEPARATOR + fileName, inputStream);
    }
    /**
     * 读取输入流中的数据写入输出流
     *
     * @param storagePath 目标文件路径
     * @param inputStream 输入流
     */
    public static void readInputStream(String storagePath, InputStream inputStream) {
        File file = new File(storagePath);
        try {
            if (file.exists()) {
                boolean b = file.delete();
                if (b) {
                    Log.d(TAG, "delete " + storagePath + " success");
                }
            }
            // 1.建立通道对象
            FileOutputStream fos = new FileOutputStream(file);
            // 2.定义存储空间
            byte[] buffer = new byte[inputStream.available()];
            // 3.开始读文件
            int lenght = 0;
            while ((lenght = inputStream.read(buffer)) != -1) {// 循环从输入流读取buffer字节
                // 将Buffer中的数据写到outputStream对象中
                fos.write(buffer, 0, lenght);
            }
            fos.flush();// 刷新缓冲区
            // 4.关闭流
            fos.close();
            inputStream.close();
            Log.d(TAG, "copy res/raw/portal.lua to " + storagePath + " success");
        } catch (FileNotFoundException e) {
            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }
    /**
     *
     * @param context 上下文对象
     * @param dir  存储目录
     * @return
     */
    public static String getFilePath(Context context,String dir) {
        String directoryPath = "";
        //判断SD卡是否可用
        if (Environment.MEDIA_MOUNTED.equals(Environment.getExternalStorageState()) ) {
            directoryPath = context.getExternalFilesDir(dir).getAbsolutePath() ;
            // directoryPath =context.getExternalCacheDir().getAbsolutePath() ;
        } else {
            //没内存卡就存机身内存
            directoryPath = context.getFilesDir() + File.separator + dir;
            // directoryPath=context.getCacheDir()+File.separator+dir;
        }
        File file = new File(directoryPath);
        if (!file.exists()) {//判断文件目录是否存在
            file.mkdirs();
        }
        return directoryPath;
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // Workaround in https://stackoverflow.com/questions/16283079/re-launch-of-activity-on-home-button-but-only-the-first-time/16447508
        if (!isTaskRoot()) {
            // Android launched another instance of the root activity into an existing task
            //  so just quietly finish and go away, dropping the user back into the activity
            //  at the top of the stack (ie: the last state of this task)
            // Don't need to finish it again since it's finished in super.onCreate .
            return;
        }
        // DO OTHER INITIALIZATION BELOW

        app = this;
        //Gengine.setVerbosity(5);
        try {
            String rootPath = this.getFilePath(this, "");
            Gengine.setDataDirectory(rootPath);
            if (!isSameFile(this, R.raw.portal, "portal.lua", rootPath)) {
                copyFilesFromRaw(this, R.raw.portal, "portal.lua", rootPath);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        SDKWrapper.getInstance().init(this);
        CAAgent.enableDebug(false);
    }
    
    @Override
    public Cocos2dxGLSurfaceView onCreateView() {
        Cocos2dxGLSurfaceView glSurfaceView = new Cocos2dxGLSurfaceView(this);
        // TestCpp should create stencil buffer
        glSurfaceView.setEGLConfigChooser(5, 6, 5, 0, 16, 8);

        SDKWrapper.getInstance().setGLSurfaceView(glSurfaceView);

        return glSurfaceView;
    }

    @Override
    protected void onResume() {
        super.onResume();
        SDKWrapper.getInstance().onResume();
        if (CAAgent.isInited())
            CAAgent.onResume(this);
    }

    @Override
    protected void onPause() {
        super.onPause();
        SDKWrapper.getInstance().onPause();
        if (CAAgent.isInited())
            CAAgent.onPause(this);
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        SDKWrapper.getInstance().onDestroy();
        if (CAAgent.isInited())
            CAAgent.onDestroy();
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        SDKWrapper.getInstance().onActivityResult(requestCode, resultCode, data);
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        SDKWrapper.getInstance().onNewIntent(intent);
    }

    @Override
    protected void onRestart() {
        super.onRestart();
        SDKWrapper.getInstance().onRestart();
    }

    @Override
    protected void onStop() {
        super.onStop();
        SDKWrapper.getInstance().onStop();
    }
        
    @Override
    public void onBackPressed() {
        SDKWrapper.getInstance().onBackPressed();
        super.onBackPressed();
    }

    @Override
    public void onConfigurationChanged(Configuration newConfig) {
        SDKWrapper.getInstance().onConfigurationChanged(newConfig);
        super.onConfigurationChanged(newConfig);
    }

    @Override
    protected void onRestoreInstanceState(Bundle savedInstanceState) {
        SDKWrapper.getInstance().onRestoreInstanceState(savedInstanceState);
        super.onRestoreInstanceState(savedInstanceState);
    }

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        SDKWrapper.getInstance().onSaveInstanceState(outState);
        super.onSaveInstanceState(outState);
    }

    @Override
    protected void onStart() {
        SDKWrapper.getInstance().onStart();
        super.onStart();
    }

    public static void showAlertDialog(final String title,final String message) {

        // 这里一定要使用 runOnUiThread
        app.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                AlertDialog alertDialog = new AlertDialog.Builder(app).create();
                alertDialog.setTitle(title);
                alertDialog.setMessage(message);
                alertDialog.show();
            }
        });
    }

    public static void openURL(String url) {
        Uri uri = Uri.parse(url);
        Intent intent = new Intent(Intent.ACTION_VIEW, uri);
        app.startActivity(intent);
    }

    public static void copyToClipboard(String addr) {
        ClipboardManager myClipboard;
        myClipboard = (ClipboardManager)app.getSystemService(CLIPBOARD_SERVICE);
    }
}
