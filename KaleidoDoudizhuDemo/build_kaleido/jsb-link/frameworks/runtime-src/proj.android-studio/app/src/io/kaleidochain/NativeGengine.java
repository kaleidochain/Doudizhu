package io.kaleidochain;

import android.util.Log;

import io.kaleidochain.gengine.Account;
import io.kaleidochain.gengine.Accounts;
import io.kaleidochain.gengine.Address;
import io.kaleidochain.gengine.EngineConfig;
import io.kaleidochain.gengine.Gengine;
import io.kaleidochain.gengine.KeyStore;
import io.kaleidochain.gengine.MnemonicInfo;
import io.kaleidochain.gengine.Node;
import io.kaleidochain.gengine.NodeConfig;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

public class NativeGengine {
    public static Node g_node;
    private final static String TAG = "NativeGengine";
    public static boolean setDataDirectory(final String dataDir) {
        try {
            Gengine.setDataDirectory(dataDir);
            Log.e(TAG, "setDataDirectory");
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
        return true;
    }

    public static void clearCache() {
        try {
            Gengine.clearCache();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public static String createAccount(final String passphase) {
        try {
            KeyStore keystore = Gengine.newKeyStore(Gengine.LightScryptN, Gengine.LightScryptP);
            MnemonicInfo info = keystore.createAccount(passphase, Gengine.ChineseSimplified);
            JSONObject result = new JSONObject();
            try {
                result.put("pubKey", info.getPubKey());
                result.put("mnemonic", info.getMnemonic());
            } catch (JSONException e) {
                e.printStackTrace();
            }
            return result.toString();
        } catch (Exception e) {
            e.printStackTrace();
            return "[]";
        }
    }

    public static boolean unlockAccountWithPassword(final String accountAddr, final String password) {
        try {
            KeyStore keystore = Gengine.newKeyStore(Gengine.LightScryptN, Gengine.LightScryptP);
            Address accountaddr = Gengine.newAddressFromHex(accountAddr);
            if (!keystore.hasAddress(accountaddr)) {
                return false;
            }
            Accounts accounts = keystore.getAccounts();
            int i = 0;
            long count = accounts.size();
            for (; i < count; i++) {
                Account account = accounts.get(i);
                Address addr = account.getAddress();
                String addrHex = addr.getHex().toLowerCase();
                if (accountAddr.toLowerCase().equals(addrHex)) {
                    keystore.unlock(account, password);
                    return true;
                }
            }
            return false;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    public static String importAccountWithPassword(final String mnemonic, final String password) {
        try {
            KeyStore keystore = Gengine.newKeyStore(Gengine.LightScryptN, Gengine.LightScryptP);
            return keystore.importAccount(mnemonic, password, Gengine.ChineseSimplified);
        } catch (Exception e) {
            e.printStackTrace();
            return "";
        }
    }

    public static String getAccounts() {
        try {
            KeyStore keystore = Gengine.newKeyStore(Gengine.LightScryptN, Gengine.LightScryptP);
            Accounts accounts = keystore.getAccounts();
            int i = 0;
            long count = accounts.size();
            JSONArray arr = new JSONArray();
            for (; i < count; i++) {
                Account account = accounts.get(i);
                Address addr = account.getAddress();
                String addrHex = addr.getHex();
                if (keystore.hasAddress(addr)) {
                    arr.put(addrHex);
                }
            }
            return arr.toString();
        } catch (Exception e) {
            e.printStackTrace();
            return "[]";
        }
    }

    public static boolean startGameEngineWithAccountAndPassword(final String account, final String password) {
        try {
            NodeConfig config = Gengine.newNodeConfig();
            EngineConfig engineconfig = Gengine.newEngineConfig();
            engineconfig.setUseAccountAddr(account);
            engineconfig.setUseAccountPassword(password);
            g_node = Gengine.newNode(config, engineconfig);
            g_node.start();
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
        return true;
    }

    public static boolean stopGameEngine() {
        try {
            if (g_node != null) {
                g_node.stop();
                g_node = null;
            }
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
        return true;
    }

    public static boolean isRunning() {
        return g_node != null;
    }

    public static int getWSPort() {
        int WSPort = 0;
        try {
            WSPort = (int)Gengine.getLocalWSPort();
        } catch (Exception e) {
            e.printStackTrace();;
            return WSPort;
        }
        return WSPort;
    }
}
