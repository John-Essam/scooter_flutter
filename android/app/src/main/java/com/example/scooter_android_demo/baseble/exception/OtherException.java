package com.example.scooter_android_demo.baseble.exception;

import com.example.scooter_android_demo.baseble.common.BleExceptionCode;

/**
 * @Description: 其他异常
 * @author: <a href="http://www.xiaoyaoyou1212.com">DAWI</a>
 * @date: 16/8/14 10:32.
 */
public class OtherException extends BleException {
    public OtherException(String description) {
        super(BleExceptionCode.OTHER_ERR, description);
    }
}
